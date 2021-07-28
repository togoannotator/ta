from collections import defaultdict
from elasticsearch.client import logger
from elasticsearch import Elasticsearch
import copy
from utils import utils
import random
import json


class EsAccessor:
    """
    Elasticsearchとのやりとりをする
    """

    def __init__(self, hosts, port: int, index_pattern: str):
        self.hosts = hosts
        self.port = port
        self.index_pattern = index_pattern
        self.es = Elasticsearch(hosts=hosts, port=port)

    @staticmethod
    def gen_reconcile_query(query_bodies: dict) -> list:
        # ESクエリを生成する
        normalized_names = []
        query_list = []
        query_body = {}

        for query_body in query_bodies:
            normalized_names.append(query_bodies[query_body]['query'])
        for normalized_name in normalized_names:
            query_file = open('src/es/query.json', mode='r')
            query = json.load(query_file)
            query['query']['bool']['must'][0]['bool']['should'][0]['bool'][
                'must'][1]['match']['normalized_name.term']['query'] = normalized_name
            query['query']['bool']['must'][0]['bool']['should'][1]['bool'][
                'must'][1]['match']['normalized_name.term']['query'] = normalized_name
            query['query']['bool']['must'][0]['bool']['should'][2]['bool'][
                'must'][1]['more_like_this']['like'] = normalized_name
            query['query']['bool']['must'][0]['bool']['should'][3]['bool'][
                'must'][1]['more_like_this']['like'] = normalized_name
            if 'limit' in query_bodies['q0'].keys():
                if type(query_bodies['q0']['limit']) != int:
                    logger.warning("limitに整数以外の値が設定されています"
                                   + str(query_bodies))
                    break
                elif int(query_bodies['q0']['limit']) > 100:
                    query['aggs']['tags']['aggs']['top_tag_hits'][
                        'top_hits']['size'] = 100
                else:
                    query['aggs']['tags']['aggs']['top_tag_hits'][
                        'top_hits']['size'] = int(
                            query_bodies['q0']['limit'])

            query_list.append(query)

        return query_list

    def msearch(self, query) -> dict:
        # ESクエリをmsearch用のクエリに修正して検索を実行する
        queies = []
        for x in query:
            head = {'index': self.index_pattern}
            body = x
            queies.extend([head, body])

        res = self.es.msearch(body=queies)
        return res

    @staticmethod
    def convert_es_response(response_bodies: dict, query_body: dict) -> dict:
        """
        Elasticsearchの検索レスポンスを加工し、DictとしてResult形式で返却する
        :param response_bodies:
        :param query_body:
        :return:
        """
        query_num = 0
        reconcile_result = {}
        try:
            for response_body in response_bodies['responses']:
                res_array = []
                es_scores = defaultdict(list)
                normalized_score = {}
                for bucket in response_body['aggregations']['tags']['buckets']:
                    # name、スコア、query_typeを取得する
                    for response in bucket['top_tag_hits']['hits']['hits']:
                        type_res = dict()
                        type_res['query_type'] = bucket['key']
                        type_res['score'] = response['sort'][0]
                        type_res['name'] = response['_source']['name']
                        res_array.append(type_res)
                        es_scores[type_res['query_type']].append(
                            type_res['score'])

                # term_after, term_before, mlt_after, mlt_beforeごとにスコアを正規化する
                normalized_score = utils.normalization_score(es_scores)

                # 正規化後のスコアに更新する
                mlt_before_cnt = mlt_after_cnt = 0
                term_before_cnt = term_after_cnt = 0

                for res in res_array:
                    if res['query_type'] == 'mlt_before':
                        res['score'] = normalized_score['mlt_before'][
                            mlt_before_cnt]
                        mlt_before_cnt += 1
                    elif res['query_type'] == 'mlt_after':
                        res['score'] = normalized_score['mlt_after'][
                            mlt_after_cnt]
                        mlt_after_cnt += 1
                    elif res['query_type'] == 'term_before':
                        res['score'] = normalized_score['term_before'][
                            term_before_cnt]
                        term_before_cnt += 1
                    elif res['query_type'] == 'term_after':
                        res['score'] = normalized_score['term_after'][
                            term_after_cnt]
                        term_after_cnt += 1
                    else:
                        logger.warning("不正なクエリタイプが設定されています" +
                                       str(res['query_type']))
                        return {}

                # スコア順にソートする
                sorted_res_array = sorted(res_array, key=lambda x:
                                          x['score'], reverse=True)

                name_list = []  # 重複を避けるためにnameのリスト
                results = []  # 最終結果を入れるためのリスト

                for sortted_res in sorted_res_array:
                    if sortted_res['name'] in name_list:
                        continue
                    else:
                        name_list.append(sortted_res['name'])
                        results.append(sortted_res)

                # limit値に基づいて返却件数を絞り込む
                results_tmp = copy.copy(results)
                results = []
                if 'limit' in query_body['q0'].keys():
                    for limit in range(query_body['q0']['limit']):
                        if len(results_tmp) > limit:
                            results.append(results_tmp[limit])
                else:
                    for limit in range(15):
                        if len(results_tmp) > limit:
                            results.append(results_tmp[limit])

                # レスポンスを生成する
                for result in results:
                    del result['query_type']
                    result['id'] = random.randrange(10**10, 10**11)
                    result['match'] = False
                    result['type'] = [{"id": "Gene Product",
                                       "name": "Gene Product"}]

                reconcile_result['q' + str(query_num)] = {"result": results}
                query_num += 1
        except Exception as e:
            logger.warning(e)

        return reconcile_result
