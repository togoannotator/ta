#!/bin/sh

curl -s -o aggs-result.json '172.18.8.190:9200/evaluation_result/_search' -H 'Content-type:application/json' -d @aggregate.json

if [ ! -f aggs-result.json ]; then
    echo "ERROR: failed to get aggregation."
    exit 1
fi

python parse-result.py aggs-result.json > aggs-result.csv
