from datetime import datetime
from glob import glob

import sys, os
sys.path.append(os.pardir)

import argparse
import getpass
import json
from loguru import logger
from es_accessor import ESAccessor
from util import Util


class Evaluation:
    """
    ElasticsearchのRanking Evaluation APIを呼び出し自動で呼び出す。
    クエリやratingsは特定ディレクトリ配下を順次読み込み利用する。
    """

    def __init__(self, index, file_type, input_path, query_name_pattern, es):
        self.body = {
            "requests": [],
            "metric": {}
        }
        self.es = es
        self.index = index
        self.file_type = file_type
        self.input_path = input_path
        self.query_name_pattern = query_name_pattern
        self.metrics = [
            {"precision": {"k": 10, "relevant_rating_threshold": 1, "ignore_unlabeled": "false"}},
            {"recall": {"k": 10, "relevant_rating_threshold": 1}},
            {"mean_reciprocal_rank": {"k": 10, "relevant_rating_threshold": 1}},
            {"dcg": {"k": 10, "normalize": "true"}},
            {"expected_reciprocal_rank": {"maximum_relevance": 10, "k": 10}}
        ]

        self.logger = logger

    def parse_doc_list(self):
        """
        self.input_path配下のディレクトリを読み込み、request bodyを構築する。
        self.input_path/* 配下には、query.jsonと、docs.ndjsonを配置する必要がある。
        :return:
        """
        self.logger.info(f'input: {self.input_path}')
        self.logger.info(f'query_name_pattern: {self.query_name_pattern}')
        self.logger.info(f'target index: {self.index}')
        dirs = glob(os.path.join(self.input_path, self.query_name_pattern))
        if len(dirs) == 0:
            raise FileNotFoundError
        for directory in dirs:
            result = {'request': {}, 'ratings': [], 'id': directory.split('/')[-1]}

            # ratingsの構築
            with open(os.path.join(directory, 'docs.' + self.file_type), encoding='utf-8') as doc_file:
                if self.file_type == 'ndjson':
                    for line in doc_file:
                        j = json.loads(line)
                        j['_index'] = self.index
                        result['ratings'].append(j)
                if self.file_type == 'tsv' or self.file_type == 'csv':
                    # tsvとcsvで区切り文字を変える
                    sep = '\t' if self.file_type == 'tsv' else self.file_type == ','
                    for line in doc_file:
                        line = line.rstrip('\n')
                        columns = line.split(sep=sep)
                        columns = [self.index] + columns  # tsvの先頭にindexカラムを追加
                        j = {
                            '_index': columns[0],
                            '_id': columns[1],
                            'rating': columns[2]
                        }
                        result['ratings'].append(j)

            # queryの構築
            with open(os.path.join(directory, 'query.json'), encoding='utf-8') as query_file:
                query = ''.join(query_file.readlines())
                result['request'] = json.loads(query)

            self.body['requests'].append(result)

    def call_rank_eval(self):
        """elasticsearch-pyの call_rank_evalを呼び出す
        :return:
        """
        return self.es.call_rank_eval(body=self.body, index=self.index)


if __name__ == '__main__':
    logger.info(sys.argv)

    parser = argparse.ArgumentParser(description='elasticsearchのranking evaluation APIを呼び出す')

    # 引数定義
    parser.add_argument('index', help='対象インデックス名/エイリアス名')
    parser.add_argument('-t', '--type', default='ndjson', help='正解ドキュメントファイルのフォーマット')
    parser.add_argument('-i', '--input', default='input', help='正解ドキュメントファイルのパス')
    parser.add_argument('--query_name_pattern', default='*', help='評価対象クエリのネームパターン。*をワイルドカードとして利用可')
    parser.add_argument('-o', '--output_dir', default='../output', help='アウトプットファイルのパス')
    parser.add_argument('-host', '--host', default='127.0.0.1', help='elasticsearchのホスト')
    parser.add_argument('-port', '--port', default=9200, help='elasticsearchのポート')
    parser.add_argument('-u', '--user', help='elasticsearchへのアクセス用ユーザー')
    parser.add_argument('-p', '--password', help='elasticsearchへのアクセス用パスワード')
    parser.add_argument('--http_proxy', help='http proxy設定')
    parser.add_argument('--https_proxy', help='https proxy設定')
    args = parser.parse_args()

    # 認証情報の設定
    if args.user:
        user = args.user
        if args.password:
            password = args.password
        else:
            password = getpass.getpass('Password: ')
    elif not args.user:
        user = 'elastic'
        password = 'changeme'

    # proxy設定
    proxies = {}
    if args.http_proxy:
        proxies['http'] = args.http_proxy
    if args.https_proxy:
        proxies['https'] = args.https_proxy

    logger.info(f'host={args.host}, port={args.port}, user={user}, password={password}, proxies={proxies}')
    es = ESAccessor(host=args.host, port=args.port, user=user, password=password, proxies=proxies)
    if not es.index_exists(args.index):
        logger.info(f'指定されたindexに接続できませんでした:{args.index}')
        exit(1)
    ev = Evaluation(index=args.index, file_type=args.type, input_path=args.input,
                    query_name_pattern=args.query_name_pattern, es=es)
    try:
        ev.parse_doc_list()
    except FileNotFoundError:
        logger.warning('対象のクエリが見つかりませんでした。')
        exit(1)

    # API呼び出しおよび結果出力
    os.makedirs(args.output_dir, exist_ok=True)
    resp = []
    today = datetime.today().strftime('%Y%m%d')
    logger.info(os.path.join(args.output_dir, f'result-{today}.json'))
    with open(os.path.join(args.output_dir, f'result-{today}.json'), 'w', encoding='utf-8') as out:
        logger.info(f'metrics: {ev.metrics}')
        for metric in ev.metrics:
            ev.body['metric'] = metric
            eval_result = ev.call_rank_eval()  # Ranking Evaluation APIを呼び出す
            resp.append(eval_result)
        out.write(json.dumps(resp, ensure_ascii=False))


    # JSON出力結果をCSVに変換して出力する
    Util.convert_output_json_to_csv(json_path=os.path.join(args.output_dir, f'result-{today}.json'),
                                    csv_path=os.path.join(args.output_dir, f'result-{today}.csv'))
