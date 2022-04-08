#!/bin/bash
set -euxo pipefail

# Detect if any changes have occured
# if python detect_source_changes.py https://nrs.objectstore.gov.bc.ca/dzzrch/fwa.gpkg.gz

    # clean out the database before re-loading
    psql $DATABASE_URL "drop schema if exists whse_basemapping cascade"
    psql $DATABASE_URL "drop schema if exists usgs cascade"
    psql $DATABASE_URL "drop schema if exists hydrosheds cascade"
    psql $DATABASE_URL "drop schema if exists postgisftw cascade"

    # run the load
    make

#fi