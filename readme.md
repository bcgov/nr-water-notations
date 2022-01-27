# Water Notations

Will contain the code required to complete the water notations
analysis including the following:

1. Helm chart to create the database, cron jobs etc required to run the analysis
1. ETL process to load the freshwater atlas, and other data required for the analysis into the database.
1. ETL process that dumps results of the analysis to object store

## Database Deployment

All aspects of this analysis including the data that goes into the
database can be created / loaded automatically.  For this reason on
this project am intentionally not using a HA deployment like Patroni
/ crunchy etc for this work.

Instead this project uses a fairly vanilla version of postgres.  Deployment is
with the helm chart in the cicd directory.
