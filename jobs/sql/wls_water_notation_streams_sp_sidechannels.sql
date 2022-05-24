-- join our streams back to fwa streams table to get watershed codes
with streams as
(
select
  a.segmented_stream_id,
  a.linear_feature_id,
  a.blue_line_key,
  a.upstream_route_measure,
  a.downstream_route_measure,
  s.watershed_key,
  s.wscode_ltree,
  s.localcode_ltree,
  s.fwa_watershed_code
from nr_water_notations.streams a
inner join whse_basemapping.fwa_stream_networks_sp s
on a.linear_feature_id = s.linear_feature_id
where s.watershed_group_code = '%s'
),

-- for null localcode side channel processing, find out if notation is located 
-- at/near mouth of stream
-- find first 3 segments in the stream
-- (presumably this cutoff will not work 100% of the time but should be fine almost)
ordered_segments as 
(
    select 
      row_number() over( partition by s.blue_line_key order by s.blue_line_key, s.downstream_route_measure) as n,
      s.linear_feature_id,
      s.blue_line_key,
      s.downstream_route_measure
    from nr_water_notations.notations n
    inner join streams s
    on n.blue_line_key = s.blue_line_key
),

start_of_stream as
(
  select 
    a.notation_id,
    a.linear_feature_id,
  case 
    when b.n <= 3 or a.downstream_route_measure < 250 then true
    else false 
  end as start_of_stream_ind
  from nr_water_notations.notations a
  inner join ordered_segments b
  on a.linear_feature_id = b.linear_feature_id
),

-- do not process streams with more than one notation on the given watershed code
streams_with_multiple_notations as
(
select distinct
  a.wscode_ltree
from nr_water_notations.notations a
inner join nr_water_notations.notations b
on a.wscode_ltree = b.wscode_ltree
  and a.notation_id != b.notation_id
  and abs(a.downstream_route_measure - b.downstream_route_measure) > 50
where a.wscode_ltree <@ '999'::ltree is false
),

-- get streams to work with - side channels with null local code
subset as (
  select distinct
    b.segmented_stream_id,
    b.linear_feature_id,
    b.blue_line_key,
    b.fwa_watershed_code,
    b.wscode_ltree,
    b.localcode_ltree,
    b.upstream_route_measure,
    b.downstream_route_measure
  from nr_water_notations.notations a
  inner join start_of_stream ss
  on a.notation_id = ss.notation_id
  inner join streams b
  on
    b.localcode_ltree is null and
    b.blue_line_key != b.watershed_key
  left outer join streams_with_multiple_notations mn
  on b.wscode_ltree = mn.wscode_ltree
  where ss.start_of_stream_ind is true
  and mn.wscode_ltree is null
),

-- join streams back to notations, sorting notations in order downstream
ordered as (
  select
    a.segmented_stream_id,
    b.notation_id,
    b.notation_type,
    a.wscode_ltree,
    a.localcode_ltree,
    a.upstream_route_measure,
    a.downstream_route_measure
  from subset a
  inner join nr_water_notations.notations b on
  fwa_downstream(
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
  or a.wscode_ltree = b.wscode_ltree
  order by
    a.segmented_stream_id,
    b.wscode_ltree desc,
    b.localcode_ltree desc,
    b.downstream_route_measure desc,
    array_position(ARRAY['FR','FR-EXC','OR','PWS','AR'], b.notation_type)
),

-- aggregate downstream notations into arrays per stream segment
aggregated as
(
  select
    segmented_stream_id,
    array_to_string(array_agg(notation_id), ';') as notation_id_list,
    (array_agg(notation_type))[1] as primary_notation_type,
    array_agg(notation_type) as all_notation_types
  from ordered
  group by
    segmented_stream_id
),

-- to collapse the distinct adjacent types,
-- extract only secondary notations and unnest the aggregation so we can use window functions
secondary_notations as
(
  select
    segmented_stream_id,
    unnest(all_notation_types[2:]) as notation_type
  from aggregated
),

-- find steps where the secondary notation type changes (also note row number
-- because the first row is not identified as a step, by labelling it we can retain it)
steps as
(
  SELECT
    row_number() over() as row,
    segmented_stream_id,
    notation_type,
    lag(segmented_stream_id||notation_type, 1, segmented_stream_id||notation_type) OVER () <> segmented_stream_id||notation_type AS step
  FROM secondary_notations
),

-- extract notation types where there is a change in type per stream segment,
-- then re-aggregate into an array
parsed_steps as
(
select
  segmented_stream_id,
  array_agg(notation_type) as secondary_notation_types
from steps
where step is true or row = 1
group by segmented_stream_id
order by segmented_stream_id
),

-- put together the secondary notation types, limiting the
-- string to 30 characters, with suffix '..' indicating overflows
-- (do not bother breaking the string at an item, just insert the .. at 28 chars)
secondary_notation_types as
(
  select
    a.segmented_stream_id,
    a.notation_id_list,
    a.primary_notation_type,
    a.all_notation_types,
    case
      when length(array_to_string(b.secondary_notation_types, ';')) < 30 then array_to_string(b.secondary_notation_types, ';')
      else substring(array_to_string(b.secondary_notation_types, ';') from 1 for 28)||'..'
    end as secondary_notation_types
from aggregated a left outer join parsed_steps b
on a.segmented_stream_id = b.segmented_stream_id
)

select
  s.linear_feature_id,
  n.notation_id_list,
  n.primary_notation_type,
  st.secondary_notation_types,
  s.fwa_watershed_code,
  s.blue_line_key,
  (st_dump(st_locatebetween
    (str.geom, s.downstream_route_measure, s.upstream_route_measure
    ))).geom as geom
from subset s
inner join aggregated n
on s.segmented_stream_id = n.segmented_stream_id
inner join whse_basemapping.fwa_stream_networks_sp str
on s.linear_feature_id = str.linear_feature_id
left outer join secondary_notation_types st
on s.segmented_stream_id = st.segmented_stream_id;
