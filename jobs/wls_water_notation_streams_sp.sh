#!/bin/bash
set -euxo pipefail


psql -c "drop schema if exists nr_water_notations cascade"
psql -c "create schema if not exists nr_water_notations"
    
# load sample features
ogr2ogr \
  -t_srs EPSG:3005 \
  -f PostgreSQL PG:$DATABASE_URL \
  -lco OVERWRITE=YES \
  -lco SCHEMA=nr_water_notations \
  -lco GEOMETRY_NAME=geom \
  -nln notations_src \
  data/notations.gdb \
  Notations_PROD_Jan26

# join points to streams
psql -f sql/notations.sql

# load all streams upstream of notations
psql -f sql/streams.sql

# break streams at notations
psql -f sql/break_streams.sql    

# make stream selection above breakpoints, add notation fields
psql -f sql/wls_water_notation_streams_sp.sql

# dump to file
mkdir -p outputs
rm -rf outputs/wls_water_notation_streams_sp.gpkg 
ogr2ogr \
  -f GPKG \
  outputs/wls_water_notation_streams_sp.gpkg \
  -nln wls_water_notation_streams_sp \
  PG:$DATABASE_URL \
  -sql "select * from nr_water_notations.wls_water_notation_streams_sp"