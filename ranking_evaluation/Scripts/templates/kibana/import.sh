#!/bin/bash

KIBANA_HOST=127.0.0.1:5601

curl "${KIBANA_HOST}"/api/saved_objects/_import -H "kbn-xsrf: true" --form file=@export.ndjson
