-- create notation table with fwa attributes
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
with src_pts as
(
	select
	  wls_wn_sysid,
	  notation_id,
	  notation_type,
	  notation_description,
	  blue_line_key,
	  geom
	from nr_water_notations.notations_src
	where blue_line_key is not null
),

nearest as
(
  select
	  pt.wls_wn_sysid,
	  pt.notation_id,
	  pt.notation_type,
	  pt.notation_description,
    str.linear_feature_id,
    str.wscode_ltree,
    str.localcode_ltree,
    str.blue_line_key,
    str.waterbody_key,
    str.length_metre,
    st_distance(str.geom, pt.geom) as distance_to_stream,
    str.watershed_group_code,
    str.downstream_route_measure as downstream_route_measure_str,
    (
      st_linelocatepoint(
        st_linemerge(str.geom),
          st_closestpoint(str.geom, pt.geom)
      )
      * str.length_metre
  ) + str.downstream_route_measure as downstream_route_measure,
  st_linemerge(str.geom) as geom_str
  from src_pts pt
  cross join lateral
  (select
     linear_feature_id,
     wscode_ltree,
     localcode_ltree,
     blue_line_key,
     waterbody_key,
     length_metre,
     downstream_route_measure,
     watershed_group_code,
     geom
    from whse_basemapping.fwa_stream_networks_sp str
    where str.localcode_ltree is not null
    and not str.wscode_ltree <@ '999'
    order by str.geom <-> pt.geom
    limit 1) as str
    where st_distance(str.geom, pt.geom) <= 100
    and pt.blue_line_key = str.blue_line_key
)

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

select
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
  st_force2d(
    st_lineinterpolatepoint(geom_str,
     round(
       cast(
          (downstream_route_measure -
             downstream_route_measure_str) / length_metre as numeric
        ),
       5)
     )
  )::geometry(point, 3005) as geom
from nearest;

create index on nr_water_notations.notations (linear_feature_id);
create index on nr_water_notations.notations (blue_line_key);
create index on nr_water_notations.notations (watershed_group_code);
create index on nr_water_notations.notations using gist (wscode_ltree);
create index on nr_water_notations.notations using btree (wscode_ltree);
create index on nr_water_notations.notations using gist (localcode_ltree);
create index on nr_water_notations.notations using btree (localcode_ltree);
create index on nr_water_notations.notations using gist (geom);