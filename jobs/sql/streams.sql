-- --------------
-- STREAMS
--
-- a copy of fwa_stream_networks_sp for breaking at notations
-- unique segmented stream id is created by combining blkey and measure
-- (with measure rounded to nearest mm, because some source stream lines are really short)
-- --------------
CREATE TABLE IF NOT EXISTS nr_water_notations.streams 
(
  segmented_stream_id       text
     GENERATED ALWAYS AS (blue_line_key::text|| '.' || round((ST_M(ST_PointN(geom, 1))) * 1000)::text) STORED PRIMARY KEY,

  -- standard fwa columns
  linear_feature_id        bigint                      ,
  edge_type                integer                     ,
  blue_line_key            integer                     ,
  watershed_key            integer                     ,
  watershed_group_code     character varying(4)        ,
  downstream_route_measure double precision
    GENERATED ALWAYS AS (ST_M(ST_PointN(geom, 1))) STORED,
  length_metre             double precision
    GENERATED ALWAYS AS (ST_Length(geom)) STORED         ,
  waterbody_key            integer                     ,
  wscode_ltree             ltree                       ,
  localcode_ltree          ltree                       ,
  gnis_name                 character varying(80)      ,
  upstream_route_measure    double precision
    GENERATED ALWAYS AS (ST_M(ST_PointN(geom, -1))) STORED,
  geom geometry(LineStringZM,3005)
);


-- load the stream data. Just load everything upstream of notations
delete from nr_water_notations.streams;
insert into nr_water_notations.streams
( linear_feature_id,
  edge_type,
  blue_line_key,
  watershed_key,
  watershed_group_code,
  waterbody_key,
  wscode_ltree,
  localcode_ltree,
  gnis_name,
  geom
)
select distinct
  b.linear_feature_id,
  b.edge_type,
  b.blue_line_key,
  b.watershed_key,
  b.watershed_group_code,
  b.waterbody_key,
  b.wscode_ltree,
  b.localcode_ltree,
  b.gnis_name,
  b.geom
from nr_water_notations.notations a
inner join whse_basemapping.fwa_stream_networks_sp b
on fwa_upstream(
  a.blue_line_key,
  a.downstream_route_measure,
  a.wscode_ltree,
  a.localcode_ltree,
  b.blue_line_key,
  b.downstream_route_measure,
  b.wscode_ltree,
  b.localcode_ltree,
  True,
  1
)
-- also include lines on which the points fall
or 
(
  a.blue_line_key = b.blue_line_key and 
  a.downstream_route_measure < b.upstream_route_measure and 
  a.downstream_route_measure >= b.downstream_route_measure
)
on conflict do nothing;

create index on nr_water_notations.streams (linear_feature_id);
create index on nr_water_notations.streams (blue_line_key);
create index on nr_water_notations.streams (watershed_group_code);
create index on nr_water_notations.streams using gist (wscode_ltree);
create index on nr_water_notations.streams using btree (wscode_ltree);
create index on nr_water_notations.streams using gist (localcode_ltree);
create index on nr_water_notations.streams using btree (localcode_ltree);
create index on nr_water_notations.streams using gist (geom);