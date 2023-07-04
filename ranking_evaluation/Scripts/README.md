# Ranking Evaluationによるクエリ評価
## 概要
Elasticsearch インデックスに対して Ranking Evaluation APIリクエストを発行し、評価値をファイル出力・Kibanaによる可視化をおこなう。
各種設定値を docker/.env ファイルに記述し、docker-composeで実行する。
なお、ダッシュボード作成は docker-composeとは別途、shellスクリプトもしくはbatスクリプトを実行する構成となっている。

### モジュール構成
#### 1. evaluator
inputフォルダ（.envで指定可能）にあるクエリおよび正解データを読み込み、outputフォルダ（.envで指定可能）に結果を出力する。正解データの形式は ndjson, csv, tsvをサポートしている。
出力結果はAPIレスポンスのJSONと、サマリ結果のCSVファイルが出力される。
#### 2. indexer
evaluatorが出力したサマリ結果のCSVを読み込み、Elasticsearchにインデキシングする。
このとき、index templateが事前に読み込まれる。

## 1. 事前準備
### クエリと正解データの準備
- inputフォルダ配下に、任意の名前のフォルダを作成し、その直下に次のファイルを作成する
    1. query.json ←評価したいクエリをjsonで記述する
    2. docs.ndjson ←正解ドキュメントのIDおよびrateを記述する
- 詳細は sample/input 配下を参照

docs.ndjsonのフォーマットは下記の通り    
```
{"_id": "1", "rating":1}
{"_id": "2", "rating":2}
{"_id": "3", "rating":3}
```

## 2. .envの設定
### docker/.envに対象インデックスやホストを記述する(example/docker/.envを参照)
.envの設定例
```
TARGET_INDEX=index_name
ES_HOST=127.0.0.1
ES_USER=elastic
ES_PASSWORD=changeme
QUERY_NAME_PATTERN="*"

# Indexer
TEMPLATE_NAME='evaluation_result'
TEMPLATE_DIR='/work/templates/elasticsearch/evaluation_result.json'

# Do NOT change settings below
INPUT_DIR=/work/input
OUTPUT_DIR=/work/output
PYTHONPATH=/work/src
```

## 3. ビルドする
```
docker-compose build --build-arg http_proxy=192.168.1.250:8080 --build-arg https_proxy=192.168.1.250:8080
```

## 4. コンテナを立ち上げる
```
docker-compose up
```

## 5. 出力された結果を確認する
出力はデフォルトで、outputフォルダに出力される (.envで指定可能)


## コマンドラインからの実行する場合
### src/evaluator、src/indexer配下からコマンドで実行が可能
#### コマンド例（sample/docker/.envに記述された、EVALUATOR_CMDなどを参考にすると良い）  
※ .envは不要。全て起動引数に含むため。
```
python evaluation.py ${TARGET_INDEX} --host ${ES_HOST} -u ${ES_USER} -i ${INPUT_DIR} --http_proxy ${HTTP_PROXY} --https_proxy ${HTTPS_PROXY} -p ${ES_PASSWORD}
```


# ダッシュボードのインポート
templates/kibana/import.bat もしくは templates/kibana/import.sh を実行する。  
この時、環境変数 KIBANA_HOSTにkibanaのURLを登録する必要がある。  
  
#### 設定例
Windows
```
set KIBANA_HOST=127.0.0.1:5601
```
Linux
```
export KIBANA_HOST=127.0.0.1:5601
```
