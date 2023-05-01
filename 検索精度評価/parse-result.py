import sys
import json

if len(sys.argv) < 2:
    print "USAGE: " + sys.argv[0] + " input-file"
    sys.exit(1)

infile=sys.argv[1]

fp = open(infile, 'r')
json_data = json.load(fp)

aggs = json_data['aggregations']
term = aggs['term_query_name']
buckets = term['buckets']

for r in buckets:
    key = r['key']
    precision = r['agg_precision']['value']
    recall = r['agg_recall']['value']
    dcg = r['agg_dcg']['value']

    print "%s,%s,%s,%s" % (key, precision, recall, dcg)
