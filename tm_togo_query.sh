#!/bin/bash

# 検索キーワードと各クエリパラメータを取得する
KEY_WORD=$2

# 検索対象インデックスを取得する
declare -A hash_
hash_["cyanobacteria"]="tm_53a186f8c95c329d6bddd8bc3d3b4189"
hash_["ecoli"]="tm_f0a37107d9735025c81673c0ad3f1109"
hash_["lab"]="tm_e854a94641613372a4170daba28407ae"
hash_["bacteria"]="tm_68c008bfb37f663c81d581287b267a20"
hash_["all"]="tm_53a186f8c95c329d6bddd8bc3d3b4189,tm_f0a37107d9735025c81673c0ad3f1109,tm_e854a94641613372a4170daba28407ae,tm_68c008bfb37f663c81d581287b267a20"
hash_["new_ecoli"]="tm_68c008bfb37f663c81d581287b267a20"
INDEX_NAME=${hash_[$1]}

echo ""
echo "Index: $1(${INDEX_NAME})"
echo ""

# パラメータを取得する
MAX_QUERY_TERMS=$3
MINIMUM_SHOULD_MATCH=$4
MIN_TERM_FREQ=$5
MIN_WORD_LENGTH=$6
MAX_WORD_LENGTH=$7


# クエリを作成する
cat << EOS > json.txt
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
EOS


# 検索処理を行い、結果を表示する
echo "===== Search query is ======"
cat json.txt | jq .
echo ""


curl -sS --noproxy localhost -X GET "http://172.18.8.190:19200/${INDEX_NAME}/_search" -H 'Content-Type: application/json' -d@json.txt > result.txt
if [ -z "$8" ]; then
echo "===== All results ====="
cat result.txt | jq
echo ""
else
echo "===== Summary results ====="
cat result.txt | jq '.aggregations.tags.buckets[].top_tag_hits.hits.hits[] | {"_score": ._score,"_source": ._source}'
echo ""
fi

