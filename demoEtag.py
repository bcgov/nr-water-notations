import minio
import os
import logging


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


class ObjectStoreUtil:
    def __init__(self):

        self.minIoClient = minio.Minio(
            CONST.OBJECTSTORE_HOST,
            CONST.OBJECTSTORE_ID,
            CONST.OBJECTSTORE_SECRET
        )

    def getEtag(self, inFilePath):
        LOGGER.debug("inFilePath: {0}".format(inFilePath))
        stat = self.minIoClient.stat_object(CONST.OBJECTSTORE_BUCKET, inFilePath)
        return stat.etag

CONST = constants()

if __name__ == '__main__':
    LOGGER = logging.getLogger()
    LOGGER.setLevel(logging.DEBUG)
    hndlr = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(lineno)d - %(message)s')
    hndlr.setFormatter(formatter)
    LOGGER.addHandler(hndlr)
    LOGGER.debug("test")



    obj = ObjectStoreUtil()

    objStoreFileName = "wls_water_notation_streams_sp.gpkg.gz"
    etag = obj.getEtag(objStoreFileName)
    print(f"etag: {etag}")










