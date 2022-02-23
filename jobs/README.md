# nr-water-notations

Select streams upstream of notations and extract.

## outline

- setup fwapg
- load notations
- convert notations to point events on streams
- load all streams upstream of notations
- break streams at notations
- extract streams upstream of notations
- join extract to notations, creating array list of notations downstream of each stream segment

## quickstart

Let's use an existing environment and db for a quick proof of concept with the provided sample data:

    conda activate bcfishpass
    ./wls_water_notation_streams.sh

## todo

- qa, lots of points are missing
- what exactly should be in `secondary_notation_types`?