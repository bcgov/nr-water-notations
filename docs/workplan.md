
Some rough notes around what needs to be done on this project and some guidance
around how to get it done.

1. Get database deployed - Mostly done (helm chart)
1. Figure out automated data load of freshwater atlas data from S3 Storage
    * should be defined in a kubernetes cronjob
    * job should monitor for changes to the data, and only update if the data has changed
1. Figure out automated data load for other input data sources
1. Work with DataBC to ensure that processes can be put into place to load data
    from S3 bucket for their processes.

