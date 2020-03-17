#!/bin/bash

INDEX_NAME=$1
KEY_WORD_FILE=$2

# MLTのパラメータを取得する
MAX_QUERY_TERMS=$3
MINIMUM_SHOULD_MATCH=$4
MIN_TERM_FREQ=$5
MIN_WORD_LENGTH=$6
MAX_WORD_LENGTH=$7

echo "検索開始"
# date

# tm_msearch.pyはmulti_searchを実行し、結果を1行で返すスクリプト
python36 tm_msearch.py --index ${INDEX_NAME} --keyword ${KEY_WORD_FILE} --max_query_terms ${MAX_QUERY_TERMS} --minimum_should_match ${MINIMUM_SHOULD_MATCH} --min_term_freq ${MIN_TERM_FREQ} --min_word_length ${MIN_WORD_LENGTH} --max_word_length ${MAX_WORD_LENGTH}

cat result.txt | jq .> result_ms.txt

echo "検索終了"
# date
