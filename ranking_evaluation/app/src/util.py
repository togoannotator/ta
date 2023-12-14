from collections import defaultdict
from datetime import datetime

from loguru import logger
import json


class Util:
    @staticmethod
    def convert_output_json_to_csv(json_path='../output/result.json', csv_path='../output/result.csv'):
        """
        Jsonで出力された、Ranking Evaluation APIの結果をCSVに変換して出力する
        :param json_path:
        :param csv_path:
        :return:
        """
        json_body = {}
        try:
            with open(json_path, 'r', encoding='utf-8') as json_file:
                json_body = json.loads(json_file.readline())
        except FileNotFoundError:
            logger.warning('Json result file NOT found. Skip converting...')
        except PermissionError:
            logger.warning('Check your permission. Skip converting...')
        except Exception as e:
            logger.warning(f'ファイルの読み込みに失敗しました：{json_path}')
            return

        # Parse result per metric
        scores = defaultdict(list)
        metric_names = []
        total_scores = []
        for metric_result in json_body:
            total_scores.append(str(metric_result['metric_score']))
            for query_name in metric_result['details']:
                metric_name = metric_result['details'][query_name]['metric_details'].popitem()[0]
                score = metric_result['details'][query_name]['metric_score']
                scores[query_name].append(str(score))
            metric_names.append(metric_name)
        header = ['id', 'query_name'] + metric_names

        # output to csv
        try:
            with open(csv_path, 'w', encoding='utf-8') as out_file:
                out_file.write(','.join(header) + '\n')  # Header
                out_file.write(','.join(['', 'total'] + total_scores) + '\n')  # Total metric score

                # Score for each query
                for num, query in enumerate(scores):
                    out_file.write(','.join([str(num), query] + scores[query]) + '\n')
        except:
            logger.warning('Failed to write... skipped.')

    @staticmethod
    def build_body(columns: list, date_time: str):
        body = {
            "id": f'{date_time}-{columns[0]}',
            "date": date_time,
            "query_name": columns[1],
            "precision": columns[2],
            "recall": columns[3],
            "mean_reciprocal_rank": columns[4],
            "dcg": columns[5],
            "expected_reciprocal_rank": columns[6]
        }
        return body
