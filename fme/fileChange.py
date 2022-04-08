import minio
import logging
import os
import sys
import argparse

LOGGER = logging.getLogger('main')

class constants:

    def __init__(self):
        # pulling the following env vars into properties of this class
        self.envVars = \
            ['OBJECTSTORE_HOST', 'OBJECTSTORE_BUCKET', 'OBJECTSTORE_ID',
                'OBJECTSTORE_SECRET']
        for envVar in self.envVars:
            if envVar not in os.environ:
                msg = "expecting the following env vars to be set and one or " + \
                      "more of them are not: " + ','.join(self.envVars)
                raise ValueError(msg)
            setattr(self, envVar, os.environ[envVar])

class ObjectHasChanged:

    def __init__(self):
        self.changeSuffix = '.etagcache'
        self.const = constants()
        self.minIoClient = minio.Minio(
            self.const.OBJECTSTORE_HOST,
            self.const.OBJECTSTORE_ID,
            self.const.OBJECTSTORE_SECRET
        )

    def hasChanged(self, inFilePath):
        hasChangedParam = True
        currentEtag = self.getCurrentEtag(inFilePath)
        cacheEtag = self.getCachedEtag(inFilePath)
        if cacheEtag == currentEtag:
            hasChangedParam = False
        return hasChangedParam

    def getCachedEtag(self, inFilePath):
        etag = None
        cacheFile = self.getCacheFileName(inFilePath)
        localFile = os.path.basename(cacheFile)
        exists = False
        try:
            retVal = self.minIoClient.fget_object(
                bucket_name=self.const.OBJECTSTORE_BUCKET, object_name=cacheFile, file_path=localFile)
            exists = True
        except minio.error.S3Error as e:
            # assume file does not exist
            ex_type, ex_value, ex_traceback = sys.exc_info()
            if 'Object does not exist' not in str(ex_value):
                # some other error
                raise
        if exists:
            with open(localFile, 'r') as fh:
                etag = fh.readline().strip()
            #except:
            if os.path.exists(localFile):
                os.remove(localFile)
        return etag

    def getCacheFileName(self, inFilePath):
        cacheFile = os.path.splitext(inFilePath)[0] + self.changeSuffix

        return cacheFile

    def getCurrentEtag(self, inFilePath):
        stat = self.minIoClient.stat_object(self.const.OBJECTSTORE_BUCKET, inFilePath)
        return stat.etag

    def syncEtag(self, inFilePath):
        currentEtag = self.getCurrentEtag(inFilePath)
        cacheFileRemote = self.getCacheFileName(inFilePath)
        cacheFileLocal = os.path.basename(cacheFileRemote)
        with open(cacheFileLocal, 'w') as fh:
            fh.write(currentEtag)
        retVal = self.minIoClient.fput_object(
            bucket_name=self.const.OBJECTSTORE_BUCKET, object_name=cacheFileRemote, file_path=cacheFileLocal
        )

    def deleteCacheFile(self, inFilePath):
        cacheFileRemote = self.getCacheFileName(inFilePath)
        LOGGER.debug("removing the file: {cacheFileRemote}")
        retVal = self.minIoClient.remove_object(self.const.OBJECTSTORE_BUCKET,
            cacheFileRemote)

class ArgHandler:

    def __init__(self):
        pass

    def defineParser(self):
        examples = """Object has changed:
                      %(prog)s -haschanged someFile2Test
                      Sync the cached info so next change reports False:
                      %(prog)s -sync someFile2Test
                      """

        parser = argparse.ArgumentParser(
            description='Change detection tool for object store',
            epilog=examples,
            formatter_class=argparse.RawDescriptionHelpFormatter)
        parser.add_argument(
            '-haschanged', '--has-object-changed', type=str,
            metavar=('inputfile'),
            nargs=1,
            help='has the input object changed')
        parser.add_argument(
            '-sync', '--sync-change-data',
            metavar=('inputfile'),
            nargs=1,
            help='sync the cached fingerprint for the file so next test would identify the file has not changed')
        parser.add_argument(
            '-remove', '--remove-cache-file',
            metavar=('inputfile'),
            nargs=1,
            help='removes the cached etag file from the object storage')
        # TODO: Add a subparser here to better describe the two args for
        # add-user

        args = parser.parse_args()
        #print(args)

        if not args.has_object_changed and \
            not args.sync_change_data and \
            not args.remove_cache_file:
            parser.print_help()
            sys.exit()

        # LOGGER.debug(f'parser: {parser}')

        # LOGGER.debug(f'args: {args}')

        if args.has_object_changed:
            # do search
            LOGGER.debug(f'input file name: {args.has_object_changed[0]}')
            obj = ObjectHasChanged()
            change = obj.hasChanged(args.has_object_changed[0])
            print(change)

        elif args.sync_change_data:
            # do search
            LOGGER.debug(f'input file name: {args.sync_change_data[0]}')
            obj = ObjectHasChanged()
            change = obj.syncEtag(args.sync_change_data[0])
            print("sync complete, etag updated")
        elif args.remove_cache_file:
            # do search
            LOGGER.debug(f'input file name: {args.remove_cache_file[0]}')
            obj = ObjectHasChanged()
            change = obj.deleteCacheFile(args.remove_cache_file[0])
            print("sync complete, etag updated")


if __name__ == '__main__':
    LOGGER = logging.getLogger()
    LOGGER.setLevel(logging.INFO)
    hndlr = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(lineno)d - %(message)s')
    hndlr.setFormatter(formatter)
    LOGGER.addHandler(hndlr)
    LOGGER.debug("test")

    args = ArgHandler()
    args.defineParser()
