create table if not exists nr_water_notations.wls_water_notation_streams_sp 
(
  linear_feature_id bigint,
  notation_id_list character varying(200),
  primary_notation_type character varying(12),
  secondary_notation_types character varying(30),
  fwa_watershed_code character varying(150),
  blue_line_key integer,
  geom geometry(Linestring, 3005)
);

delete from nr_water_notations.wls_water_notation_streams_sp;

-- get streams to work with
with subset as (
  select distinct
    b.segmented_stream_id,
    b.linear_feature_id,
    b.blue_line_key,
    s.fwa_watershed_code,
    b.wscode_ltree,
    b.localcode_ltree,
    b.downstream_route_measure,
    st_force2d(b.geom) as geom
  from nr_water_notations.notations a
  inner join nr_water_notations.streams b
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
  inner join whse_basemapping.fwa_stream_networks_sp s
  on b.linear_feature_id = s.linear_feature_id
  --where a.watershed_group_code = 'VICT' and fwa_watershed_code like ('925-303570-916663%')  -- testing
),

-- join streams back to notations, sorting notations in order downstream
ordered as
(
  select 
    a.segmented_stream_id,
    b.notation_id,
    b.notation_type,
    a.geom
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
    order by
      a.segmented_stream_id,
      b.wscode_ltree desc,
      b.localcode_ltree desc,
      b.downstream_route_measure desc
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

insert into nr_water_notations.wls_water_notation_streams_sp 
(
  linear_feature_id,
  notation_id_list,
  primary_notation_type,
  secondary_notation_types,
  fwa_watershed_code,
  blue_line_key,
  geom
)

select 
  s.linear_feature_id,
  n.notation_id_list,
  n.primary_notation_type,
  st.secondary_notation_types,
  s.fwa_watershed_code,
  s.blue_line_key,
  s.geom
from subset s 
inner join aggregated n
on s.segmented_stream_id = n.segmented_stream_id
left outer join secondary_notation_types st
on s.segmented_stream_id = st.segmented_stream_id