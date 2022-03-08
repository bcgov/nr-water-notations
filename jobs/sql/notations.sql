-- ----------------------------------------------------
-- Match notations to streams
-- Join source notation points to the closest fwa stream segment with matching blue_line_key
-- ----------------------------------------------------

-- create target table
drop table if exists nr_water_notations.notations;
create table nr_water_notations.notations (
	wls_wn_sysid          integer                ,
	notation_id           character varying(20)  ,
	notation_type         character varying(20)  ,
	notation_description  character varying(140) ,
	linear_feature_id     bigint                 ,
	blue_line_key         integer                , 
	downstream_route_measure double precision    ,
	wscode_ltree          ltree                  ,
	localcode_ltree       ltree                  ,  
	distance_to_stream    double precision       ,
	watershed_group_code  character varying(4)   ,
	geom                  geometry(point,3005) 
);


-- populate the table
insert into nr_water_notations.notations (
	wls_wn_sysid,
	notation_id,
	notation_type,
	notation_description,
	linear_feature_id,
	blue_line_key,
	downstream_route_measure,
	wscode_ltree,
	localcode_ltree,
	distance_to_stream,
	watershed_group_code,
	geom
)

-- We know which stream to join to (blkey) but need to find the 
-- closest point on closest segment with the matching blkey
select distinct on (notation_id)  -- distinct notation_id in case segments are equidistant
  pt.wls_wn_sysid,
  pt.notation_id,
  pt.notation_type,
  pt.notation_description,
  nn.linear_feature_id,
  pt.blue_line_key,
  (ST_LineLocatePoint(
    nn.geom,
    ST_ClosestPoint(nn.geom, pt.geom)
    ) * nn.length_metre) + nn.downstream_route_measure AS downstream_route_measure,
  nn.wscode_ltree,
  nn.localcode_ltree,
  nn.distance_to_stream,
  nn.watershed_group_code,
  st_force2d(
    postgisftw.fwa_locatealong(
      pt.blue_line_key, 
      (ST_LineLocatePoint(
        nn.geom,
        ST_ClosestPoint(nn.geom, pt.geom)
      ) * nn.length_metre) + nn.downstream_route_measure
    )
  ) as geom
from nr_water_notations.notations_src as pt
cross join lateral
(select
   str.linear_feature_id,
   str.wscode_ltree,
   str.localcode_ltree,
   str.blue_line_key,
   str.waterbody_key,
   str.watershed_key,
   str.gnis_name,
   str.length_metre,
   str.downstream_route_measure,
   str.watershed_group_code,
   str.geom,
   st_distance(str.geom, pt.geom) as distance_to_stream
  from whse_basemapping.fwa_stream_networks_sp as str  
  where pt.blue_line_key = str.blue_line_key
  order by str.geom <-> pt.geom
  limit 1) as nn
order by notation_id, distance_to_stream;

create index on nr_water_notations.notations (linear_feature_id);
create index on nr_water_notations.notations (blue_line_key);
create index on nr_water_notations.notations (watershed_group_code);
create index on nr_water_notations.notations using gist (wscode_ltree);
create index on nr_water_notations.notations using btree (wscode_ltree);
create index on nr_water_notations.notations using gist (localcode_ltree);
create index on nr_water_notations.notations using btree (localcode_ltree);
create index on nr_water_notations.notations using gist (geom);