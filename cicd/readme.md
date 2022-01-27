# Steps taken to create the chart

# Artifactory setup
This doc provides guidance on the setup of artifactory:
https://developer.gov.bc.ca/Artifact-Repositories-(Artifactory)

## Artifactory setup steps taken:


### Create artifactory Secret

Steps outlined [here](https://developer.gov.bc.ca/Artifact-Repositories-(Artifactory)#can-we-have-more-than-one-artifactory-service-account)

```
oc process -f https://raw.githubusercontent.com/bcgov/platform-services-archeobot/master/archeobot/config/samples/tmpl-artifactoryserviceaccount.yaml -p NAME="artifact" -p DESCRIPTOR="artifactory service account" | oc create -f -```
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

```
cd cicd
helm upgrade --install water-notations water-notations
```

# Background Information

postgres/gis image:
https://registry.hub.docker.com/r/postgis/postgis
