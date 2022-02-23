---------------------------------------------------------------
-- create a temp table where we segment streams at point locations
---------------------------------------------------------------
create temporary table temp_streams as

-- because we are rounding the measure, collapse any duplicates with distinct
-- note that rounding only works (does not potentially shift the point off of stream of interest)
-- because we are joining only if the point is not within 1m of the endpoint
with breakpoints as
(
  select distinct
    blue_line_key,
    round(downstream_route_measure::numeric)::integer as downstream_route_measure
  from nr_water_notations.notations
),

to_break as
(
  select
    s.segmented_stream_id,
    s.linear_feature_id,
    s.downstream_route_measure as meas_stream_ds,
    s.upstream_route_measure as meas_stream_us,
    b.downstream_route_measure as meas_event
  from
    nr_water_notations.streams s
    inner join breakpoints b
    on s.blue_line_key = b.blue_line_key and
    -- match based on measure, but only break stream lines where the
    -- barrier pt is >1m from the end of the existing stream segment
    (b.downstream_route_measure - s.downstream_route_measure) > 1 and
    (s.upstream_route_measure - b.downstream_route_measure) > 1
),

-- derive measures of new lines from break points
new_measures as
(
  select
    segmented_stream_id,
    linear_feature_id,
    --meas_stream_ds,
    --meas_stream_us,
    meas_event as downstream_route_measure,
    lead(meas_event, 1, meas_stream_us) over (partition by segmented_stream_id
      order by meas_event) as upstream_route_measure
  from
    to_break
)

-- create new geoms
select
  n.segmented_stream_id,
  s.linear_feature_id,
  n.downstream_route_measure,
  n.upstream_route_measure,
  (st_dump(st_locatebetween
    (s.geom, n.downstream_route_measure, n.upstream_route_measure
    ))).geom as geom
from new_measures n
inner join nr_water_notations.streams s 
on n.segmented_stream_id = s.segmented_stream_id;


---------------------------------------------------------------
-- shorten existing stream features
---------------------------------------------------------------
with min_segs as
(
  select distinct on (segmented_stream_id)
    segmented_stream_id,
    downstream_route_measure
  from
    temp_streams
  order by
    segmented_stream_id,
    downstream_route_measure asc
),

shortened as
(
  select
    m.segmented_stream_id,
    st_length(st_locatebetween(s.geom, s.downstream_route_measure, m.downstream_route_measure)) as length_metre,
    (st_dump(st_locatebetween (s.geom, s.downstream_route_measure, m.downstream_route_measure))).geom as geom
  from min_segs m
  inner join nr_water_notations.streams s
  on m.segmented_stream_id = s.segmented_stream_id
)

update
  nr_water_notations.streams a
set
  geom = b.geom
from
  shortened b
where
  b.segmented_stream_id = a.segmented_stream_id;


---------------------------------------------------------------
-- now insert new features
---------------------------------------------------------------
insert into nr_water_notations.streams
(
  linear_feature_id,
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
select
  t.linear_feature_id,
  s.edge_type,
  s.blue_line_key,
  s.watershed_key,
  s.watershed_group_code,
  s.waterbody_key,
  s.wscode_ltree,
  s.localcode_ltree,
  s.gnis_name,
  t.geom
from temp_streams t
inner join whse_basemapping.fwa_stream_networks_sp s
on t.linear_feature_id = s.linear_feature_id
on conflict do nothing;