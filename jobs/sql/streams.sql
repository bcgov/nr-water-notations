insert into nr_water_notations.streams
( linear_feature_id,
  blue_line_key,
  watershed_key,
  downstream_route_measure,
  upstream_route_measure,
  watershed_group_code
)

select distinct
  b.linear_feature_id,
  b.blue_line_key,
  b.watershed_key,
  b.downstream_route_measure,
  b.upstream_route_measure,
  b.watershed_group_code
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
-- also include side channels with equivalent wscodes and null localcodes
-- (these are impossible to exactly locate without delving into network traces,
-- but we can include them in this first pass and include only those that
-- are likely to be upstream of a given notation in subsequent steps)
or
(
  a.wscode_ltree = b.wscode_ltree and
  b.localcode_ltree is null and
  b.blue_line_key != b.watershed_key
)
where a.watershed_group_code = :'wsg'
on conflict do nothing;