import argparse
import getpass
import json
import time
from datetime import datetime

import sys, os

sys.path.append(os.pardir)

from es_accessor import ESAccessor
from loguru import logger
import requests
from util import Util


class Indexer:
    def __init__(self, name: str, input_dir: str, template_path: str, es: ESAccessor):
        self.es = es
        self.name = name
        self.input_dir = input_dir
        self.template_path = template_path
        self.logger = logger
        now = datetime.today()
        self.today = now.strftime('%Y%m%d')
        self.date_time = now.strftime('%Y%m%d-%H%M')

    def put_index_template(self, body):
        self.es.put_index_template(self.name, body)

    def index_result(self):
        input_path = os.path.join(self.input_dir, f'result-{self.today}.csv')
        logger.info(f'input: {input_path}')

        # evaluatorの処理を待つ。
        loop_count = 30
        for i in range(loop_count):
            # タイムアウト処理
            if i == loop_count-1:
                raise FileNotFoundError(input_path)
            time.sleep(10)
            try:
                result_file = open(input_path, 'r', encoding='utf-8')
                break
            except:
                logger.info('waiting for result file...')

        next(result_file)  # ヘッダ行をスキップ
        next(result_file)  # 集計行をスキップ

        for line in result_file:
            line = line.rstrip('\n')
            body = Util.build_body(line.split(','), self.date_time)
            self.es.index(self.name, body, body["id"])

        result_file.close()


if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='elasticsearchのranking evaluation APIを呼び出す')

    # 引数定義
    parser.add_argument('name', help='template名')
    parser.add_argument('-i', '--input', default='input', help='')
    parser.add_argument('-host', '--host', default='127.0.0.1', help='elasticsearchのホスト')
    parser.add_argument('-port', '--port', default=9200, help='elasticsearchのポート')
    parser.add_argument('-u', '--user', help='elasticsearchへのアクセス用ユーザー')
    parser.add_argument('-p', '--password', help='elasticsearchへのアクセス用パスワード')
    parser.add_argument('-t', '--template', default='templates/elasticsearch/evaluation_result.json', help='')
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

    es = ESAccessor(host=args.host, port=args.port, user=user, password=password, proxies=proxies)
    indexer = Indexer(name=args.name, input_dir=args.input, template_path=args.template, es=es)

    # index template の登録
    with open(indexer.template_path, 'r', encoding='utf-8') as template_file:
        body = json.load(template_file)
        indexer.put_index_template(body)
    logger.info('put index template.')

    # 評価結果のインデクシング
    logger.info('start indexing evaluation result')
    indexer.index_result()
