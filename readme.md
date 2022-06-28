# Overview - Water Notations Data Pipeline

Code in this repository exists to support the data pipeline that generates
notation streams and notation aquifers (`WLS_WATER_NOTATION_STREAMS_SP`, `WLS_WATER_NOTATION_AQUIFERS_SP`) based on the following inputs:

* Stream Notation Points - (BCGW)
* Freshwater Atlas - (cached version in Object Store)
* Aquifers (BCGW)

The analysis runs in openshift and does the following:

* check for changes to FWA data on object store on a scheduled basis
* if FWA data has changed, reload the `fwapg` database to openshift
* download notation points on scheduled basis, check for changes
* if change to notations is detected, injest notations into the `fwapg` database,
run the analysis, export to file and copy output .gpkg to object store

On DataBC side:

* an FMW will run daily monitoring the streams notation layer.  If it has
  changed it will be injested into the BCGW oracle database.

# Technical Details

## Database / Cronjob Deployments

The cicd directory contains a helm chart that will deploy all the components
associated with the analysis.

Deploying the helm chart will create the following components:
* postgres/gis database (db, pvc, service etc..)
* secrets with the database connection information
* a cron job that executes daily that will update the stream notation data
  if any of the input data has changed.

to run deployment

```
cd cicd
helm upgrade --install water-notations water-notations
```


# Troubleshooting make file / load

* run the helm chart
* get a list of the pods and identify the one that is running called dataload-something
* login and do the debugging
`oc rsh <pod name>`


### Deploy helm chart

```
cd cicd
helm upgrade --install water-notations water-notations
```

### Manually trigger job

`oc create job  "dataload-manual-$(date +%s)" --from=cronjob/dataload`


`oc create job  temp-dataload-1 --from=cronjob/dataload`


# Background Information

### postgres/gis image:
https://registry.hub.docker.com/r/postgis/postgis

### Data Loading job

* defined in the helm chart in the cicd directory (dataloadjob.yaml)
* schedule is currently set to run at midnight
* source repository for the image: https://github.com/franTarkenton/fwapg
* source image: https://hub.docker.com/repository/docker/guylafleur/gdal-util

### Water Notations Analysis

* defined in the helm chart in the cicd directory (notationsjob.yaml)
* schedule is currently set to run at noon
* source repository for the image: https://github.com/smnorris/fwapg
* source image: https://hub.docker.com/repository/docker/snorris75/gdal-util







# Working with Postgres/gis

set up port forwarding:

`oc get pods`

find the pod name that is running postgres/gis.  Likely starts with waternote-postgres-blahblah

`oc port-forward <pod name> 5432:5432`

login to database after port forwarding is set up:

`psql <db name> -U <db user> -h 0.0.0.0`

# Automate Data Load

Created the dataload job that loads the data using the Makefile in this repo:
https://github.com/franTarkenton/fwapg

## todo:
* stream


