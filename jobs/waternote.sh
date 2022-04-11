#!/bin/bash
set -euxo pipefail

# 1. dump notations via WFS and load to objectstore (for easy change detection)
#bcdata dump WHSE_WATER_MANAGEMENT.WLS_WATER_NOTATION_SV > wls_water_notation_sv.geojson
python tos3.py wls_water_notation_sv.geojson

# 2. detect if any changes have occured, run the job if they have
if python fileChange.py -haschanged wls_water_notation_sv.geojson | grep -q 'True'; then

    # clear out working schema
    psql $DATABASE_URL -c "drop schema if exists nr_water_notations cascade"
    psql $DATABASE_URL -c "create schema if not exists nr_water_notations"

    # load notations
    ogr2ogr \
      -s_srs EPSG:4326 \
      -t_srs EPSG:3005 \
      -f PostgreSQL PG:$DATABASE_URL \
      -lco OVERWRITE=YES \
      -lco SCHEMA=nr_water_notations \
      -lco GEOMETRY_NAME=geom \
      -nln notations_src \
      wls_water_notation_sv.geojson \
      Notations_PROD_Jan26             # TODO - change layer name for prod data

    # load aquifers
    # (there is no need to detect changes in this one, so direct to db)
    bcdata bc2pg --db_url $DATABASE_URL WHSE_WATER_MANAGEMENT.GW_AQUIFERS_CLASSIFICATION_SVW

    # join points to streams
    psql $DATABASE_URL -f sql/notations.sql

    # load all streams upstream of notations
    psql $DATABASE_URL -f sql/streams.sql

    # break streams at notations
    psql $DATABASE_URL -f sql/break_streams.sql

    # make stream selection above breakpoints, add notation fields
    psql $DATABASE_URL -f sql/wls_water_notation_streams_sp.sql

    # find aquifers that intersect notations
    psql $DATABASE_URL -f sql/wls_water_notation_aquifers_sp.sql

    # clear out any old outputs
    rm -rf wls_water_notation_streams_sp.*
    rm -rf wls_water_notation_aquifers_sp.*

    # dump outputs to file
    ogr2ogr \
      -f GPKG \
      wls_water_notation_streams_sp.gpkg \
      -nln wls_water_notation_streams_sp \
      PG:$DATABASE_URL \
      -sql "select * from nr_water_notations.wls_water_notation_streams_sp"

    ogr2ogr \
      -f GPKG \
      wls_water_notation_aquifers_sp.gpkg \
      -nln wls_water_notation_aquifers_sp \
      PG:$DATABASE_URL \
      -sql "select * from nr_water_notations.wls_water_notation_aquifers_sp"

    # compress the outputs
    zip -r wls_water_notation_streams_sp.gpkg.zip wls_water_notation_streams_sp.gpkg
    zip -r wls_water_notation_aquifers_sp.gpkg.zip wls_water_notation_aquifers_sp.gpkg

    # move to object store
    python tos3.py wls_water_notation_streams_sp.gpkg.zip
    python tos3.py wls_water_notation_aquifers_sp.gpkg.zip

    # with job complete, sync etag info to s3 so it does not get re-run on same file
    python fileChange.py -sync wls_water_notation_sv.geojson
fi
