# Steps taken to create the chart

# Artifactory setup
This doc provides guidance on the setup of artifactory:
https://developer.gov.bc.ca/Artifact-Repositories-(Artifactory)

## Artifactory setup steps taken:

### Create artifactory Secret

Steps outlined [here](https://developer.gov.bc.ca/Artifact-Repositories-(Artifactory)#can-we-have-more-than-one-artifactory-service-account)

```
oc process -f https://raw.githubusercontent.com/bcgov/platform-services-archeobot/master/archeobot/config/samples/tmpl-artifactoryserviceaccount.yaml -p NAME="artifact" -p DESCRIPTOR="artifactory service account" | oc create -f -
```

## Deployment

Deploy the helm chart, the postgres/gis image is comming from dockerhub, with
artifactory in the middle to cache the images.

For a quick summary of how to modify the image reference for a dockerhub image
to an artifactory image:

Docker image:
`postgis/postgis:14-3.2-alpine` or `docker.io/postgis/postgis:14-3.2-alpine`

Changes to:
```
artifacts.developer.gov.bc.ca/docker-remote/postgis/postgis:14-3.2-alpine
```

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


