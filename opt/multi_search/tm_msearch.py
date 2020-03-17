#!/usr/bin/env python
from elasticsearch import Elasticsearch
import argparse
import json
import time

# タンパク質を複数検索語で一度に検索するクラス
class ProteinMultiSearch(object):
    # 検索キーワードと各クエリパラメータを取得する
    def __init__(self, index_name, max_query_terms, minimum_should_match, min_term_freq, min_word_length, max_word_length):
        self.hash_index = {'cyanobacteria': 'tm_53a186f8c95c329d6bddd8bc3d3b4189', 'ecoli': 'tm_f0a37107d9735025c81673c0ad3f1109', 'lab': 'tm_e854a94641613372a4170daba28407ae',  'bacteria': 'tm_68c008bfb37f663c81d581287b267a20'}
        self.translated_index_name = self.hash_index[index_name]
        self.mlt_params = {'max_query_terms': max_query_terms, 'minimum_should_match': minimum_should_match, 'min_term_freq': min_term_freq, 'min_word_length': min_word_length, 'max_word_length': max_word_length}

    # keyword_listをクエリに展開できる形に変換する
    def convert_to_list(self, file_path):
        with open(file_path, encoding="utf-8") as f:
            keyword_list=[]
            line = f.readline()
            while line:
                keyword_list.append(line.rstrip('\n'))
                line = f.readline()
        return keyword_list

    # MultiSearchのクエリを作成する
    def create_query(self, keyword_list):
        query = []
        for keyword in keyword_list:
            query.append({"index" : self.translated_index_name})
            query.append(
                {
                    "query": {
                        "bool": {
                            "should": [
                                {
                                    "bool": {
                                        "must": [
                                            {"term": {"query_type": "term_before"}},
                                            {"match": {"normalized_name.term": {"query": keyword}}}
                                        ]
                                    }
                                },
                                {
                                    "bool": {
                                        "must": [
                                            {"term": {"query_type": "term_after"}},
                                            {"match": {"normalized_name.term": {"query": keyword}}}
                                        ]
                                    }
                                },
                                {
                                    "bool": {
                                        "must": [
                                            {"term": {"query_type": "mlt_before"}},
                                            {
                                                "more_like_this": {
                                                    "fields": ["normalized_name.mlt"],
                                                    "like": keyword,
                                                    "max_query_terms": str(self.mlt_params['max_query_terms']),
                                                    "minimum_should_match": self.mlt_params['minimum_should_match'],
                                                    "min_term_freq": str(self.mlt_params['min_term_freq']),
                                                    "min_word_length": str(self.mlt_params['min_word_length']),
                                                    "max_word_length": str(self.mlt_params['max_word_length'])
                                                }
                                            }
                                        ]
                                    }
                                },
                                {
                                    "bool": {
                                        "must": [
                                            {"term": {"query_type": "mlt_after"}},
                                            {
                                                "more_like_this": {
                                                    "fields": ["normalized_name.mlt"],
                                                    "like": keyword,
                                                    "max_query_terms": str(self.mlt_params['max_query_terms']),
                                                    "minimum_should_match": self.mlt_params['minimum_should_match'] ,
                                                    "min_term_freq": str(self.mlt_params['min_term_freq']),
                                                    "min_word_length": str(self.mlt_params['min_word_length']),
                                                    "max_word_length": str(self.mlt_params['max_word_length'])
                                                }
                                            }
                                        ]
                                    }
                                }
                            ]
                        }
                    },
                    "size": 0,
                    "aggregations": {
                        "tags": {
                            "terms": {
                                "field": "query_type",
                                "size": 4
                            },
                            "aggs": {
                                "top_tag_hits": {
                                    "top_hits": {
                                        "size": 15
                                    }
                                }
                            }
                        }
                    }
                }
            )
        return query

    # 検索処理を実行する
    def msearch_protein(self, host, query):
        self.es_client = Elasticsearch(host)
        es = Elasticsearch(host)
        response = es.msearch(body=query, request_timeout=150)
        # filter_pathを設定する場合は以下を利用する
        #response = es.msearch(body=query_text, request_timeout=150, filter_path=['responses.aggregations.tags.buckets.key','responses.aggregations.tags.buckets.top_tag_hits.hits.hits._score','responses.aggregations.tags.buckets.top_tag_hits.hits.hits._source.name','responses.aggregations.tags.buckets.top_tag_hits.hits.hits._source.normalized_name'])
        return response

if __name__ == "__main__":

    # 開始時刻
    t1 = time.time()
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", type=str)
    parser.add_argument("--keyword", type=str)
    parser.add_argument("--max_query_terms", type=int)
    parser.add_argument("--minimum_should_match", type=str)
    parser.add_argument("--min_term_freq", type=int)
    parser.add_argument("--min_word_length", type=int)
    parser.add_argument("--max_word_length", type=int)
    args = parser.parse_args()

    msearcher = ProteinMultiSearch(args.index, args.max_query_terms, args.minimum_should_match, args.min_term_freq, args.min_word_length, args.max_word_length)
    query_text = msearcher.create_query(msearcher.convert_to_list(args.keyword))

    t2 = time.time()
    result_text = msearcher.msearch_protein("localhost:19200", query_text)
    t3 = time.time()
    # queryの出力
    with open('query.txt','w') as f:
        json.dump(query_text, f)

    # msearch結果の出力
    #with open('result.txt', 'w') as f:
    #    json.dump(result_text, f)
    
    # 終了時刻
    t4 = time.time()

    search_time = t3-t2
    print(f"検索時間：{search_time} 秒")
