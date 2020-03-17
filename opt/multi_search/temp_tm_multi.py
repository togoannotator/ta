#!/usr/bin/env python
from elasticsearch import Elasticsearch
import argparse
import json
import time

query_text = open("query.txt", "r")
query = query_text.read()

t2 = time.time()
es = Elasticsearch("localhost:19200")
result_text = es.msearch(body=query, request_timeout=150)

t3 = time.time()
with open('result.txt', 'w') as f:
    json.dump(result_text, f)
    
t4 = time.time()

search_time = t3-t2
print(search_time)
