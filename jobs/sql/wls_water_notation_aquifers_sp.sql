create table if not exists nr_water_notations.wls_water_notation_aquifers_sp 
(
  aquifer_id integer,
  notation_id character varying(10),
  notation_description character varying(140),
  geom geometry(MultiPolygon, 3005)
);

delete from nr_water_notations.wls_water_notation_aquifers_sp;


insert into nr_water_notations.wls_water_notation_aquifers_sp 
(
  aquifer_id,
  notation_id,
  notation_description,
  geom
)

select 
  a.aquifer_id,
  n.notation_id,
  n.notation_description,
  st_multi(a.geom) as geom
from nr_water_notations.notations_src n
inner join whse_water_management.gw_aquifers_classification_svw a
on a.aquifer_id = split_part(n.notation_description, ' - ', 1)::integer
-- Aquifers are identified by a number and then the dash eg 1010 - 
-- If there is a mix of numbers and letters before the first dash (-), 
-- such as this example, it is not an aquifer  117 MILE CREEK - FR - 1986/06/23
where notation_description ~ '^[0-9]+ -.*$' 
order by aquifer_id, notation_description;

-- report on unmatched notations 
-- (and do a spatial join to aquifers in hopes that something matches)
-- select 
--   n.notation_id,
--   n.notation_description,
--   a2.aquifer_id
-- from nr_water_notations.notations_src n
-- left outer join whse_water_management.gw_aquifers_classification_svw a
-- on a.aquifer_id = split_part(n.notation_description, ' - ', 1)::integer
-- inner join whse_water_management.gw_aquifers_classification_svw a2
-- on st_intersects(n.geom, a2.geom)
-- where notation_description ~ '^[0-9]+ -.*$' and a.aquifer_id is null
-- order by notation_description;
