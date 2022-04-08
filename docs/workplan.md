
# Overview

Some rough notes around what needs to be done on this project and some guidance
around how to get it done.

1. Get database deployed - Mostly done (helm chart)
1. Figure out automated data load of freshwater atlas data from S3 Storage
    * should be defined in a kubernetes cronjob
    * job should monitor for changes to the data, and only update if the data has changed
1. Figure out automated data load for other input data sources
1. Work with DataBC to ensure that processes can be put into place to load data
    from S3 bucket for their processes.

# 4-7-2021

* FWA - Injestion.
    * double check that it is setup to only replicate if the data has changed
    * script to replicate it is (fwapg.sh)

* Notation points
    * how are these getting into the object store.
    * is this process automated?
    * ideally set up so that the notations file is only created if the data
      has changed

* Kevin Actions
    * send simon python code example for getting etag out of object store
    * Hand off the task of automating the FWA data dump to S3 storage
    * once simon generates the gpkg for the output data modify the FMW's that
      will get sent to databc
    * convert oc jobs to cron jobs for fwa injestion, and others
    * Update helm chart with increased database resources for
        * cpu
        * memory

    * add cron job that runs every minute that makes sure all the relevant files
      in the object store are public accessible.

* Simon Actions
    * modify process that generates the notations using bcdata to use zip and
      not gz
    * Add change detection to script that updates the streams / aquifers so that
      it only runs if the notations have changed
