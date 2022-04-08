"""
Code here will get put into an FME transformer to support the ability to detect
file change on an object storage object.

How it works?

a) Inputs: name / path to a file in object storage
b) script will look for the eqivalent file with a .filechange suffix on it
   if that file doesn't exist it is created and the contents of the objects
   etag is copied to that file
c) if the file does exist the contents of the file are compared with the etag
   that exists in object storage.  If they differ the file has changed, if they
   are the same the file has not changed.
"""

import os
import requests
import logging
import sys
import io
from urlparse import urlparse



LOGGER = logging.getLogger()

class ModuleInit:
    """ this is a hack to handle the s3 dependencies this module will search
        the directory that this script is being run in for the minio module.
        it it cannot be found then the class will install it
    """

    def __init__(self):
        self.installdir = 'pydeps'
        self.configurePaths()
        try:
            LOGGER.debug("importing minio")
            global minio
            import minio
        except:
            LOGGER.info("fetching the minio module")
            self.install()

    def configurePaths(self):
        # FME_MF_DIR_UNIX_MASTER
        try:
            curDir = os.path.dirname(__file__)
        except NameError:
            import fme
            #print '-'*80
            #for var in fme.macroValues:
            #    print var, "'", fme.macroValues[var]
            curDir = os.path.realpath(fme.macroValues['FME_MF_DIR_UNIX_MASTER'])


        #curDir = os.path.dirname(__file__)
        self.depDir = os.path.realpath(os.path.join(curDir, self.installdir))
        if not os.path.exists(self.depDir):
            os.mkdir(self.depDir)
        pathList = os.environ['PATH'].split(';')
        pathList.insert(0, self.depDir)
        sys.path.insert(0, self.depDir)
        LOGGER.debug("depdir: {0}".format(self.depDir))

    def install(self):
        trustParams = "--trusted-host pypi.org --trusted-host pypi.python.ordfg --trusted-host files.pythonhosted.org"
        #pipInstall = 'pip install {0} -t {1} minio --global http.sslVerify false'.format(trustParams, depDir)
        pipInstall = 'python -m pip install -t {0} minio==5.0.10'.format( self.depDir)
        LOGGER.debug(pipInstall)
        print pipInstall
        os.system(pipInstall)

        #LOGGER.debug("var: {0}".format(os.environ['PATH']))
        import minio


class constants:
    def __init__(self):
        self.envVars = ['OBJECTSTORE_HOST', 'OBJECTSTORE_BUCKET', 'OBJECTSTORE_ID',
                'OBJECTSTORE_SECRET']
        try:
            import fme
            self.getFMEMacroVars()
        except ImportError:
            self.getEnvVars()


    def getFMEMacroVars(self):
        for envVar in self.envVars:
            if envVar not in fme.macroValues:
                msg = "Expecting the following published parameter: {0} to exist but it cannot be found".format(envVar)
                raise ValueError(msg)
            else:
                setattr(self, envVar, fme.macroValues[envVar])

    def getEnvVars(self):
        # slurping the list of env vars below into constants
        for envVar in self.envVars:
            if envVar not in os.environ:
                msg = "expecting the following env vars to be set and one or " + \
                      "more of them are not: " + ','.join(self.envVars)
                raise ValueError(msg)
            setattr(self, envVar, os.environ[envVar])

class ObjectChange:

    def __init__(self):
        self.installer = ModuleInit()
        self.changeSuffix = '.filechange'
        LOGGER.debug("connecting to object storage")
        self.minIoClient = minio.Minio(
            CONST.OBJECTSTORE_HOST,
            CONST.OBJECTSTORE_ID,
            CONST.OBJECTSTORE_SECRET
        )

    def fixPath(self, inputFile):
        """ the input file can be a url path, if this is the case the assumption is that
        it takes this format:

        https://<obj store domain>/<bucket name>/<path to object>

        This method will extract the object name/path from the url.

        :param path: input path
        :type path:str

        """
        t = urlparse(inputFile)
        path = t.path
        path = path.replace("/" + CONST.OBJECTSTORE_BUCKET, '')
        if path[0] == '/':
            path = path[1:]
        LOGGER.debug("new path: {0}".format(path))
        return path

    def calcChangeFile(self, inputFilePath, dbenv):
        changeFilePath = os.path.splitext(inputFilePath)[0] + '.' + dbenv + self.changeSuffix
        return changeFilePath

    def listObjects(self, inDir=None, recursive=True,
                    returnFileNamesOnly=False):
        """lists the objects in the object store.  Run's recursive, if
        inDir arg is provided only lists objects that fall under that
        directory
        :param inDir: The input directory who's objects are to be listed
                      if no value is provided will list all objects in the
                      bucket
        :type inDir: str
        :return: list of the object names in the bucket
        :rtype: list
        """
        LOGGER.debug("indir: {0}".format(inDir))
        if inDir is None:
            inDir = '/'
        objects = self.minIoClient.list_objects(
            CONST.OBJECTSTORE_BUCKET,
            recursive=False,
            prefix=inDir
        )
        retVal = objects
        if returnFileNamesOnly:
            LOGGER.debug("getting only object names")
            retVal = []
            for obj in objects:
                retVal.append(obj.object_name)
        LOGGER.debug("objects: {0}".format(objects))
        return retVal

    def fileExists(self, inFile=None):
        exists = False
        inPath = os.path.dirname(inFile)
        fileList = self.listObjects(inPath, returnFileNamesOnly=True)
        for curFile in fileList:
            LOGGER.debug("file: {0}".format(curFile))
            if curFile == inFile:
                exists = True
                break
        return exists

    def getEtag(self, inFilePath):
        LOGGER.debug("inFilePath: {0}".format(inFilePath))
        #stat_object(bucket_name, object_name, ssec=None, version_id=None, extra_query_params=None)
        stat = self.minIoClient.stat_object(CONST.OBJECTSTORE_BUCKET, inFilePath)
        # for attr in dir(stat):
        #    LOGGER.debug("obj.%s = %r" % (attr, getattr(stat, attr)))
        #	opts.UserMetadata["x-amz-acl"] = "public-read"
        # userMetaData := map[string]string{"x-amz-acl": "public-read"}
	    # n, err := minioClient.PutObject(bucketName, objectName, fileObject, contentLength, minio.PutObjectOptions{ContentType: contentType, CacheControl: cacheControl, UserMetadata: userMetaData})
        return stat.etag

    def createAndUploadChangeFile(self, inFilePath, changeFilePath):
        LOGGER.debug("inFilePath: {0}".format(inFilePath))
        etag = self.getEtag(inFilePath)

        etagBytes = etag.encode('utf-8')
        etagStream = io.BytesIO(etagBytes)

        retVal = self.minIoClient.put_object(
            CONST.OBJECTSTORE_BUCKET,
            changeFilePath,
            etagStream,
            length=len(etagBytes))
        LOGGER.debug("return value from upload of etag for file: {0} is {1}".format(changeFilePath, retVal))

    def getCachedEtag(self, inFilePath, dbenv):
        fileChangeFile = self.calcChangeFile(inFilePath, dbenv)
        resp = self.minIoClient.get_object(CONST.OBJECTSTORE_BUCKET, fileChangeFile)
        LOGGER.debug("resp.data: {0}".format(resp.data))
        LOGGER.debug("resp: {0}".format(resp))
        return resp.data

    def hasChanged(self, inFilePath, dbEnv):
        """Returns a true or false that indicates if the input file has changed
        """
        LOGGER.info("Checking the file {0} to see if it has changed")
        hasChanged = False
        changeFilePath = self.calcChangeFile(inFilePath, dbEnv)
        LOGGER.debug("change file: {0}".format(changeFilePath))
        if not self.fileExists(changeFilePath):
            LOGGER.debug("The file: {0} does not exist".format(changeFilePath))
            LOGGER.debug("The input file: {0}".format(inFilePath))

            #self.createAndUploadChangeFile(inFilePath, changeFilePath)
            # first time through if the file change file does not exist then
            # assumption is made that the data has changed.
            hasChanged = True
        else:
            # etag exists... now download the file change and the current
            # etag on the file.  Compare to determine change
            LOGGER.debug("change file found!  getting etag data")
            currentEtag = self.getEtag(inFilePath)
            LOGGER.debug("current etag: {0}".format(currentEtag))
            cachedEtag = self.getCachedEtag(inFilePath, dbEnv)
            LOGGER.debug("cached etag: {0}".format(cachedEtag))
            if cachedEtag != currentEtag:
                hasChanged = True
        return hasChanged

CONST = constants()


class S3ChangeDetector(object):
    def __init__(self):
        self.srcFile = fme.macroValues['SRC_DATASET_GPKG_1']
        self.dbenv = fme.macroValues['DEST_DB_ENV_KEY']

        self.objChng = ObjectChange()
        self.fixedFile = self.objChng.fixPath(self.srcFile)
        LOGGER.debug("fixed file path is: {0}".format(self.fixedFile))
        self.objectChangeStatus = self.objChng.hasChanged(self.fixedFile, self.dbenv)

    def input(self,feature):
        #if self.objectChangeStatus is None:
        #    dataSet = feature.getAttribute('fme_dataset')
        #    self.objectChangeStatus = self.objChng.hasChanged(dataSet)

        if self.objectChangeStatus:
            feature.setAttribute('CHANGE_DETECTED', 'TRUE')
        else:
            feature.setAttribute('CHANGE_DETECTED', 'FALSE')
        self.pyoutput(feature)  # pylint: disable=no-member

    def close(self):
        if self.objectChangeStatus:
            # update the change file
            changeFilePath = self.objChng.calcChangeFile(self.fixedFile, self.dbenv)
            self.objChng.createAndUploadChangeFile(self.fixedFile, changeFilePath)




if __name__ == '__main__':
    LOGGER = logging.getLogger()
    LOGGER.setLevel(logging.DEBUG)
    hndlr = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(lineno)d - %(message)s')
    hndlr.setFormatter(formatter)
    LOGGER.addHandler(hndlr)
    LOGGER.debug("test")


    print("running")
    objChng = ObjectChange()
    objChng.fileList()