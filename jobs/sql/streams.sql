insert into nr_water_notations.streams
( linear_feature_id,
  blue_line_key,
  downstream_route_measure,
  upstream_route_measure
)

with lowest_notations as
(
select distinct
   a.*
from nr_water_notations.notations a
left outer join nr_water_notations.notations b
on fwa_downstream(
  a.blue_line_key,
  a.downstream_route_measure,
  a.wscode_ltree,
  a.localcode_ltree,
  b.blue_line_key,
  b.downstream_route_measure,
  b.wscode_ltree,
  b.localcode_ltree,
  False,
  1
)
where a.watershed_group_code = :'wsg'
and b.notation_id is null
)

select distinct
  b.linear_feature_id,
  b.blue_line_key,
  b.downstream_route_measure,
  b.upstream_route_measure
from lowest_notations a
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