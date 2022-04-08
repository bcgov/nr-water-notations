# FME custom components

## Background

Water notations data flow:

1. New Water notations are posted to the S3 bucket
1. Kubernetes cron job run nightly at 11 picks up the changes
1. postgis process is run to generate new water notations data, and is then
   exported to a file geodatabase (geopkg?)
1. DataBC FME jobs runs nightly, checks for changes and loads new data.

## FME Process

The water notations data, especially the streams can take a significant amount
of time to load.  Existing file change detection methods used at databc do not
work when the data is stored in s3 compatible object storage.

A custom transformer was created in to support S3 object storage file change
detection.

## Requirements

The following published parameters must be populated in the FMW in order for
the custom transformer to be able to communciate with object storage

### S3 Object permissions

Currently in order for the process to work the input object / FGDB in s3, needs
to be publically accessible with a url that resembles:
`https://<object storage host>/<bucket>/<path and file def>`

for example:
`https://nrs.objectstore.gov.bc.ca/dzzrch/wls_water_notation_aquifers_sp.gdb.zip`

### python:

Keeping with DataBC configuration, these scripts are designed to work with
python 27

### Parameters:

* **SRC_DATASET_FGDB_1** this is a published parameter that the file change uses
to identify what the source dataset is.  This parameter is hardwired at the moment.
* **OBJECTSTORE_HOST** host of the object storage, Example: `nrs.objectstore.gov.bc.ca`
* **OBJECTSTORE_SECRET** the secret that is used to authenticate to object storage
* **OBJECTSTORE_ID** the object storage id / user, used in combination with the secret to authenticate
* **OBJECTSTORE_BUCKET** the name of the bucket in object store to connect to


## Functionality - How it works

* change detector looks at the parameter defined in `SRC_DATASET_FGDB_1` and
  it looks for a similar file with a `.filechange` suffix

* the `.filechange` file contains a cached version of the s3 objects etag
  attribute.  If the file exists, file change will compare the cached etag with
  the etag that is associated with the object.  If they are different the file
  has changed since the last replication, otherwise the change detector infers
  that the object has not changed.

* if the `*.filechange` file does not exist, its assumed that the file HAS changed
  and the replication should proceed.  At the conclusion of the replication a
  new `*.filechange` file is generated.

## Possible future work

* remove dependency on `SRC_DATASET_FGDB_1` and have the code retrieve the input
  s3 object from the first feature through the *fme_dataset* property, example: `dataSet = feature.getAttribute('fme_dataset')`




