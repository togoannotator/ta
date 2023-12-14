curl %KIBANA_HOST%/api/saved_objects/_import -H "kbn-xsrf: true" --form file=@export.ndjson -u elastic
