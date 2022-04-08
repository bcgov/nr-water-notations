#!/bin/bash
set -euxo pipefail

# 1. dump notations from WFS to geojson
# bcdata dump WHSE_WATER_MANAGEMENT.WLS_WATER_NOTATION_SV > wls_water_notation_sv.geojson

# 2. detect if any changes have occured
# if python detect_source_changes.py wls_water_notation_sv.geojson

# 3. Run the job if changes detected
# then
    # clear out working schema
    psql -c "drop schema if exists nr_water_notations cascade"
    psql -c "create schema if not exists nr_water_notations"

    # load notations
    ogr2ogr \
      -s_srs EPSG:3005 \
      -t_srs EPSG:3005 \
      -f PostgreSQL PG:$DATABASE_URL \
      -lco OVERWRITE=YES \
      -lco SCHEMA=nr_water_notations \
      -lco GEOMETRY_NAME=geom \
      -nln notations_src \
      wls_water_notation_sv.geojson \
      Notations_PROD_Jan26             # test layer name

    # load aquifers
    # (there is no need to detect changes in this one, so direct to db)
    bcdata bc2pg --db_url $DATABASE_URL WHSE_WATER_MANAGEMENT.GW_AQUIFERS_CLASSIFICATION_SVW

    # join points to streams
    psql -f sql/notations.sql

    # load all streams upstream of notations
    psql -f sql/streams.sql

    # break streams at notations
    psql -f sql/break_streams.sql

    # make stream selection above breakpoints, add notation fields
    psql -f sql/wls_water_notation_streams_sp.sql

    # find aquifers that intersect notations
    psql -f sql/wls_water_notation_aquifers_sp.sql

    # clear out any old outputs
    rm -rf outputs
    mkdir -p outputs

    # dump outputs to file
    ogr2ogr \
      -f GPKG \
      outputs/wls_water_notation_streams_sp.gpkg \
      -nln wls_water_notation_streams_sp \
      PG:$DATABASE_URL \
      -sql "select * from nr_water_notations.wls_water_notation_streams_sp"

    ogr2ogr \
      -f GPKG \
      outputs/wls_water_notation_aquifers_sp.gpkg \
      -nln wls_water_notation_aquifers_sp \
      PG:$DATABASE_URL \
      -sql "select * from nr_water_notations.wls_water_notation_aquifers_sp"

    # compress the outputs
    gzip outputs/wls_water_notation_streams_sp.gpkg
    gzip outputs/wls_water_notation_aquifers_sp.gpkg

    # move to object store

# fi