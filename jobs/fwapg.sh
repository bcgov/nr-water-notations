#!/bin/bash
set -euxo pipefail

# Detect changes in fwa.gpkg.gz on object store and run job if file has changed
# if python detect_source_changes.py https://nrs.objectstore.gov.bc.ca/dzzrch/fwa.gpkg.gz; then

    # delete existing fwa archive
    rm -rf data/fwa.gpkg

    # clean out the database before re-loading
    psql $DATABASE_URL -c "drop schema if exists whse_basemapping cascade"
    psql $DATABASE_URL -c "drop schema if exists usgs cascade"
    psql $DATABASE_URL -c "drop schema if exists hydrosheds cascade"
    psql $DATABASE_URL -c "drop schema if exists postgisftw cascade"

    # run the load
    make

#fi