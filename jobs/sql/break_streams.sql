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
    nr_water_notations.streams_test s
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

-- and insert the new records
select
  n.segmented_stream_id,
  s.linear_feature_id,
  s.blue_line_key,
  n.downstream_route_measure,
  n.upstream_route_measure
from new_measures n
inner join nr_water_notations.streams_test s 
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
)

update
  nr_water_notations.streams_test a
set
  upstream_route_measure = b.downstream_route_measure --geom = b.geom
from
  min_segs b
where
  b.segmented_stream_id = a.segmented_stream_id;


---------------------------------------------------------------
-- now insert new features
---------------------------------------------------------------
insert into nr_water_notations.streams_test
(
  linear_feature_id,
  blue_line_key,
  downstream_route_measure,
  upstream_route_measure
)
select
  linear_feature_id,
  blue_line_key,
  downstream_route_measure,
  upstream_route_measure
from temp_streams
on conflict do nothing;