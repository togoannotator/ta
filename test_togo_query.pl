#!/usr/bin/env perl

use strict;
use warnings;
use WWW::Curl::Easy;
 
# Setting the options
my $curl = WWW::Curl::Easy->new();
my $response_body;
my $lcquery = "protein";
my $INDEX_NAME = "tm_53a186f8c95c329d6bddd8bc3d3b4189";
$curl->setopt(CURLOPT_URL, "http://localhost:9200/${INDEX_NAME}/_search");
$curl->setopt(CURLOPT_POST, 1);
$curl->setopt(CURLOPT_HTTPHEADER, [
	"Content-Type: application/json",
]);
my $KEY_WORD = $lcquery;
my $MAX_QUERY_TERMS = 100;
my $MINIMUM_SHOULD_MATCH = "30%";
my $MIN_TERM_FREQ = 0;
my $MIN_WORD_LENGTH = 0;
my $MAX_WORD_LENGTH = 0;
my $query2es =<<"QUERY";
{
  "query": {
    "bool": {
      "should": [
        {
          "bool": {
            "must": [
              {
                "term": {
                  "query_type": "term_before"
                }
              },
              {
                "match": {
                  "normalized_name.term": {
                    "query": "${KEY_WORD}"
                  }
                }
              }
            ]
          }
        },
        {
          "bool": {
            "must": [
              {
                "term": {
                  "query_type": "term_after"
                }
              },
              {
                "match": {
                  "normalized_name.term": {
                    "query": "${KEY_WORD}"
                  }
                }
              }
            ]
          }
        },
        {
          "bool": {
            "must": [
              {
                "term": {
                  "query_type": "mlt_before"
                }
              },
              {
                "more_like_this": {
                  "fields": [
                    "normalized_name.mlt"
                  ],
                  "like": "${KEY_WORD}",
                  "max_query_terms": ${MAX_QUERY_TERMS},
                  "minimum_should_match": "${MINIMUM_SHOULD_MATCH}",
                  "min_term_freq": ${MIN_TERM_FREQ},
                  "min_word_length": ${MIN_WORD_LENGTH},
                  "max_word_length":  ${MAX_WORD_LENGTH}
                }
              }
            ]
          }
        },
        {
          "bool": {
            "must": [
              {
                "term": {
                  "query_type": "mlt_after"
                }
              },
              {
                "more_like_this": {
                  "fields": [
                    "normalized_name.mlt"
                  ],
                  "like": "${KEY_WORD}",
                  "max_query_terms": ${MAX_QUERY_TERMS},
                  "minimum_should_match": "${MINIMUM_SHOULD_MATCH}",
                  "min_term_freq": ${MIN_TERM_FREQ},
                  "min_word_length": ${MIN_WORD_LENGTH},
                  "max_word_length": ${MAX_WORD_LENGTH}
                }
              }
            ]
          }
        }
      ]
    }
 },
  "size": 0, 
  "aggs": {  },
  "aggs": {
    "tags": {
      "terms": {
        "field": "query_type",
        "size": 4
      },
      "aggs":{
        "top_tag_hits":{
          "top_hits": {
            "size": 15
          }
        }
      }
    }
  }
}
QUERY

print $query2es;
$curl->setopt(CURLOPT_POSTFIELDS, $query2es);

# NOTE - do not use a typeglob here. A reference to a typeglob is okay though.
open (my $fileb, ">", \$response_body);
$curl->setopt(CURLOPT_WRITEDATA,$fileb);
 
# Starts the actual request
my $retcode = $curl->perform;
 
# Looking at the results...
if ($retcode == 0) {
        print("Transfer went ok\n");
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        # judge result and next action based on $response_code
        print("Received response: $response_body\n");
} else {
        print("An error happened: ".$curl->strerror($retcode)." ($retcode)\n");
}
