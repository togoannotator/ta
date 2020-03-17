#!/bin/bash

# 検索キーワードと各クエリパラメータを取得する
SCRIPT_DIR=$(cd `dirname $0`; pwd)
KEY_WORD=$3

# 検索対象インデックスを取得する
declare -A hash_
hash_["cyanobacteria"]="mlttest_dict_53a186f8c95c329d6bddd8bc3d3b4189"
hash_["ecoli"]="mlttest_dict_f0a37107d9735025c81673c0ad3f1109"
hash_["bacteria"]="mlttest_dict_68c008bfb37f663c81d581287b267a20"
hash_["all"]="mlttest_dict_53a186f8c95c329d6bddd8bc3d3b4189,mlttest_dict_f0a37107d9735025c81673c0ad3f1109,mlttest_dict_68c008bfb37f663c81d581287b267a20"
INDEX_NAME=${hash_[$1]}

# タイプを取得する
declare -A type_
type_["D"]="wospconvtableD"
type_["E"]="wospconvtableE"
TYPE_NAME=${type_[$2]}

echo ""
echo "Index: $1(${INDEX_NAME})"
echo "type : ${TYPE_NAME}"
echo ""

# パラメータを取得する
sudo cat << EOS > mlt_params.txt
MAX_QUERY_TERMS=$4
MINIMUM_SHOULD_MATCH=$5
MIN_TERM_FREQ=$6
MIN_WORD_LENGTH=$7
MAX_WORD_LENGTH=$8
EOS

source ${SCRIPT_DIR}/mlt_params.txt
MAX_QUERY_TERMS=$MAX_QUERY_TERMS
MINIMUM_SHOULD_MATCH=$MINIMUM_SHOULD_MATCH
MIN_TERM_FREQ=$MIN_TERM_FREQ
MIN_WORD_LENGTH=$MIN_WORD_LENGTH
MAX_WORD_LENGTH=$MAX_WORD_LENGTH


# クエリを作成する
sudo cat << EOS > json.txt
{
    "_source": ["name","normalized_name","frequency","orgName"],
    "query": {
        "more_like_this" : {
            "fields": [
              "normalized_name"
            ],
            "like": "${KEY_WORD}",
            "max_query_terms": ${MAX_QUERY_TERMS},
            "minimum_should_match": "${MINIMUM_SHOULD_MATCH}",
            "min_term_freq": ${MIN_TERM_FREQ},
            "min_word_length": ${MIN_WORD_LENGTH},
            "max_word_length": ${MAX_WORD_LENGTH}
        }
    },
    "size": 10000
}
EOS

# 検索処理を行い、結果を表示する
echo "===== Search query is ======"
sudo cat json.txt | jq .
echo ""


sudo curl -sS --noproxy localhost -X GET "http://localhost:9200/${INDEX_NAME}/${TYPE_NAME}/_search" -H 'Content-Type: application/json' -d@json.txt > result.txt

if [ -z "$9" ]; then
echo "===== All results ====="
sudo cat result.txt | jq
echo ""
else
echo "===== Sumary results ====="
#cat result.txt | jq '{"_score":.hits.hits[]._score, "_source":.hits.hits[]._source}'
sudo cat result.txt | jq '.hits.hits[] | {"_score": ._score,"_source": ._source}'
echo ""
fi

