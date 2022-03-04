#!/bin/bash
set -euxo pipefail

psql -c "drop schema if exists nr_water_notations cascade"
psql -c "create schema if not exists nr_water_notations"
    
# load sample notations
ogr2ogr \
  -t_srs EPSG:3005 \
  -f PostgreSQL PG:$DATABASE_URL \
  -lco OVERWRITE=YES \
  -lco SCHEMA=nr_water_notations \
  -lco GEOMETRY_NAME=geom \
  -nln notations_src \
  data/notations.gdb \
  Notations_PROD_Jan26

# load aquifers
bcdata bc2pg $DATABASE_URL WHSE_WATER_MANAGEMENT.GW_AQUIFERS_CLASSIFICATION_SVW

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

# dump to file (.fgb for now, no .gdb driver on dev machine)
ogr2ogr \
  -f FlatGeobuf \
  outputs/wls_water_notation_streams_sp.fgb \
  -nln wls_water_notation_streams_sp \
  PG:$DATABASE_URL \
  -sql "select * from nr_water_notations.wls_water_notation_streams_sp"

ogr2ogr \
  -f FlatGeobuf \
  outputs/wls_water_notation_aquifers_sp.fgb \
  -nln wls_water_notation_aquifers_sp \
  PG:$DATABASE_URL \
  -sql "select * from nr_water_notations.wls_water_notation_aquifers_sp"

