create table if not exists nr_water_notations.wls_water_notation_aquifers_sp 
(
  aquifer_id integer,
  notation_id character varying(10),
  notation_description character varying(140),
  geom geometry(MultiPolygon, 3005)
);

delete from nr_water_notations.wls_water_notation_aquifers_sp;

-- not sure how to identify aquifer based notations.
-- for testing:
-- use all PWS notations with no blue_line_key, and find
-- intersecting aquifer, but return only the notation/aquifer pair 
-- of the notation closest to the centre of the aquifer

insert into nr_water_notations.wls_water_notation_aquifers_sp 
(
  aquifer_id,
  notation_id,
  notation_description,
  geom
)

select distinct on (aquifer_id)
  a.aquifer_id,
  n.notation_id,
  n.notation_description,
  st_multi(a.geom) as geom
from nr_water_notations.notations_src n
inner join whse_water_management.gw_aquifers_classification_svw a
on st_contains(a.geom, n.geom)
where 
  blue_line_key is null and 
  n.notation_type = 'PWS'
order by aquifer_id, st_distance(n.geom, st_centroid(a.geom));