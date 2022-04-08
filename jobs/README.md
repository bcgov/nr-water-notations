# nr-water-notations

Spatial queries to translate water notation points `WLS_WATER_RESERVATION_SV` into:

- `WLS_WATER_NOTATION_STREAMS_SP` - streams upstream of notations
- `WLS_WATER_NOTATION_AQUIFERS_SP` - aquifers associated with notations

## Tasks

- setup and load postgres/postgis FWA database via `fwapg`
- on scheduled basis
    + request notations from BCGW and dump to file 
    + compare downloaded notations to previous download, terminate if data unchanged

If source data changed:

- load notations to db
- convert notation geoms to point locations on streams (`blue_line_key`/`downstream_route_measure`), linking only features with a `blue_line_key` in the source data
- break stream features at notation points
- find all resulting stream features upstream of notations
- create strings that list notations downstream of a given stream segment
- process aquifers (simple spatial join, linking aquifer based notations to aquifers)
- dump results of queries to .gpkg as per spec below
- upload resulting .gpkg to objectstore

## Data spec

## Input notations

Sample data for now:

    $ ogrinfo wls_water_notation_sv.geojson Notations_PROD_Jan26 -so
    INFO: Open of `wls_water_notation_sv.geojson'
          using driver `GeoJSON' successful.

    Layer name: Notations_PROD_Jan26
    Geometry: Point
    Feature Count: 4932
    Extent: (512994.580200, 372000.978400) - (1814716.555300, 1693592.725400)
    Layer SRS WKT:
    PROJCRS["NAD83 / BC Albers",
    ...etc....
    WLS_WN_SYSID: Integer (0.0)
    NOTATION_ID: String (0.0)
    NOTATION_TYPE: String (0.0)
    NOTATION_DESCRIPTION: String (0.0)
    BLUE_LINE_KEY: Integer (0.0)
    LATITUDE: Real (0.0)
    LONGITUDE: Real (0.0)
    SE_ANNO_CAD_DATA: String (0.0)


## Output tables

### Streams

| NAME                     | TYPE     | LENGTH  | DESCRIPTION |
|--------------------------|----------|---------|-------------|
| LINEAR_FEATURE_ID        | Number   | 18      | A primary key to link the stream segments in WHSE_BASEMAPPING_FWA_STREAM_NETWORKS_SP
| NOTATION_ID_LIST         | Varchar2 | 200     | A list of all Notation points downstream from the stream segment.
| PRIMARY_NOTATION_TYPE    | Varchar2 | 12      | Indicates the type of Notation point downstream from the stream segment, i.e., Application refused (AR); Possible Water Shortage (PWS); Fully recorded (FR); Fully Recorded Except (FR-EXC); Office Reserve (OR).
| SECONDARY_NOTATION_TYPES | Varchar2 | 30      | Secondary Notation Type is a list of the notation_type of all notations downstream of the primary notation type, in order downstream, with adjacent equivalent types removed. Where the string is > 30 char, indicate there are more types with '..' suffix after 28char
| FWA_WATERSHED_CODE       | Varchar2 | 150     | A 143 character code derived using a hierarchy.
| BLUE_LINE_KEY            | Number   | 10      | Uniquely identifies a single flow line such that a main channel and a secondary channel with the same watershed code would have different blue line keys (the Fraser River and all side channels have different blue line keys).


### Aquifers

| NAME                     | TYPE     | LENGTH  | DESCRIPTION |
|--------------------------|----------|---------|-------------|
| AQUIFER_ID               | Varchar2 |  150    | Number assigned to the aquifer. It is widely used by ground water administration staff as it is the only consistent unique identifier for a mapped aquifer. |
| NOTATION_ID              | Varchar2 |   10    | A unique identifier assigned to each Notation, e.g., NO12345.|
|NOTATION_DESCRIPTION      |Varchar2  |  140    | This field indicates the water source the Notation is on, the type of notation and the efective date of the notation e.g., 1120 - PWS - 2011/09/29 (Aquifer Number - Notation Type-Effective Date) | 


## Usage

- ensure environment variable `$DATABASE_URL` points to appropriate db

- load FWA to `$DATABASE_URL` - this takes some time:
    
        ./fwapg.sh

- download notations and run the job if notations have changed:
        
        ./waternote.sh