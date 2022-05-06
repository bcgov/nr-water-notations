#!/bin/bash
set -euxo pipefail

# Kludge to get the OGR to work with the container that was built and being
# run in openshift... To address this issue:
# https://github.com/OSGeo/gdal/issues/4570
DATABASE_URL_OGR=$DATABASE_URL?application_name=foo

# 1. dump notations via WFS and load to objectstore (for easy change detection)
bcdata dump WHSE_WATER_MANAGEMENT.WLS_WATER_NOTATION_SV > wls_water_notation_sv.geojson
python tos3.py wls_water_notation_sv.geojson

# 2. detect if any changes have occured, run the job if they have
if python fileChange.py -haschanged wls_water_notation_sv.geojson | grep -q 'True'; then
    # clear out working schema
    psql $DATABASE_URL -c "drop schema if exists nr_water_notations cascade"
    psql $DATABASE_URL -c "create schema if not exists nr_water_notations"

    # clear out any old outputs
    rm -rf wls_water_notation_streams_sp.*
    rm -rf wls_water_notation_aquifers_sp.*

    # load notations
    ogr2ogr \
      -s_srs EPSG:4326 \
      -t_srs EPSG:3005 \
      -f PostgreSQL PG:$DATABASE_URL_OGR \
      -lco OVERWRITE=YES \
      -lco SCHEMA=nr_water_notations \
      -lco GEOMETRY_NAME=geom \
      -nln notations_src \
      wls_water_notation_sv.geojson \
      wls_water_notation_sv

    # join points to streams
    psql $DATABASE_URL -f sql/notations.sql

    # ---------------------
    # process streams
    # ---------------------
    # create a table of streams to work with, everything upstream of notations
    psql $DATABASE_URL -c "CREATE TABLE IF NOT EXISTS nr_water_notations.streams
    (
      segmented_stream_id       text
         GENERATED ALWAYS AS (blue_line_key::text|| '.' || round((downstream_route_measure * 1000))::text) STORED PRIMARY KEY,
      linear_feature_id        bigint,
      blue_line_key integer,
      downstream_route_measure double precision,
      upstream_route_measure    double precision,
      watershed_group_code character varying(4)
    );
    truncate nr_water_notations.streams;"

    # load data per watershed group so we do not overwhelm the db resources
    for wsg in $(psql $DATABASE_URL -AtX -c "select distinct watershed_group_code
        from nr_water_notations.notations
        order by watershed_group_code")
    do
        psql $DATABASE_URL -f sql/streams.sql -v wsg=$wsg
    done

    # break streams (in table created above) at notations
    psql $DATABASE_URL -f sql/break_streams.sql

    # generate empty output gpkg
    ogr2ogr \
      -f GPKG \
      -nlt LINESTRING \
      -a_srs EPSG:3005 \
      -nln wls_water_notation_streams_sp \
      wls_water_notation_streams_sp.gpkg \
      PG:"$DATABASE_URL_OGR" \
      -sql "select
        linear_feature_id::bigint,
        ''::character varying(200) as notation_id_list,
        ''::character varying(12) as primary_notation_type,
        ''::character varying(30) as secondary_notation_types,
        fwa_watershed_code::character varying(150),
        blue_line_key::integer,
        st_force2d(geom)::geometry(Linestring, 3005)
       from whse_basemapping.fwa_stream_networks_sp
       limit 0"

    # dump output streams per watershed group
    for WSG in $(psql $DATABASE_URL -AtX \
        -c "select distinct watershed_group_code
            from nr_water_notations.streams
            order by watershed_group_code")
    do
        SQL=$(cat sql/wls_water_notation_streams_sp.sql)
        echo "Dumping $WSG to file"
        ogr2ogr \
            -f GPKG \
            -append \
            -update \
            -nln wls_water_notation_streams_sp \
            wls_water_notation_streams_sp.gpkg \
            PG:$DATABASE_URL_OGR \
            -sql "${SQL/'%s'/$WSG}"
    done

    # ---------------------
    # process aquifers
    # ---------------------
    # load aquifers
    # (there is no need to detect changes in this one, so direct to db)
    bcdata bc2pg --db_url $DATABASE_URL WHSE_WATER_MANAGEMENT.GW_AQUIFERS_CLASSIFICATION_SVW

    # Process aquifers (simply find aquifers that intersect notations)
    psql $DATABASE_URL -f sql/wls_water_notation_aquifers_sp.sql

    # dump output aquifers to file
    ogr2ogr \
      -f GPKG \
      wls_water_notation_aquifers_sp.gpkg \
      -nln wls_water_notation_aquifers_sp \
      PG:$DATABASE_URL_OGR \
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
