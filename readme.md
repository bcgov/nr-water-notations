# Overview - Water Notations Data Pipeline

Code in this repository exists to support the data pipeline that will calculate
stream notations based on the following inputs:
* Freshwater Atlas - (Cached version in Object Store)
* Aquifers (BCGW)
* Stream Notation Points - (BCGW)

The Analysis runs in openshift and will do the following:
* check for changes in the FWA data, Stream Notations, Aquifers
* if change is detected the the changed data will be injested into the
   postgres/gis database in openshift
* if any data has been updated it will trigger the analysis resulting in a
  new stream notations layer in the database
* streams notation layer is the exported and copied to object store.

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


## Outstanding issues

Most of the workflows are defined... the next step is to get them
* Need to get everything all automated

