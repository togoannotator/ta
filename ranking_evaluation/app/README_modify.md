# Ranking Evaluationによるクエリ評価
## 概要
Elasticsearch インデックスに対して Ranking Evaluation APIリクエストを発行し、評価値をファイル出力・Kibanaによる可視化をおこなう。各種設定値を `docker/.env` ファイルに記述したdocker-composeで起動および実行する。なお、ダッシュボード作成は docker-composeとは別途、shellスクリプトもしくはbatスクリプトを実行する構成となっており、最終的にはシェルスクリプトで結果のCSVデータを出力する

## 実行手順
### 1. mkdocs.pyを利用してクエリデータと正解データの生成
```
python3 mkdocs.py <input-file.tsv>
```

* inputフォルダ配下に、任意の名前のフォルダを作成し、その直下に次のファイルを作成する。詳細は `sample/input` 配下を参照。
* inputディレクトリ配下にクエリと正解データは、簡易ツール`mkdocs.py` を利用して、生成することができる。ツールは、Python3で動作する。
* あらかじめ、同ディレクトリにquery.templateファイルを置き、以下のコマンドを実行する。
* すでに出力されているデータは削除しない。同じ名前ならば上書きするが、変更されなかったファイルはそのまま残るので注意。

### 2. docker-composeをセットアップ後実行することでクエリ評価を実施する

`docker/.env`を編集し、対象インデックスやホストを記述し、コンテナをビルド後に起動することで、`output`フォルダに出力される。出力先ディレクトリは`.env`で指定可能。

```
vi docker/.env
docker-compose build
docker-compose up
```

プロキシの指定が必要な場合は、以下のようにオプションを指定する。
```
docker-compose build --build-arg http_proxy=192.168.1.250:8080 --build-arg https_proxy=192.168.1.250:8080
```

## 3. ダッシュボードのインポート
`templates/kibana/import.sh` を実行する。この時、環境変数 `KIBANA_HOST` にKibanaのIPアドレスとポート番号を登録する必要がある。
Windowsの場合は`templates/kibana/import.bat` を実行する。

### 設定例
`templates/kibana/import.sh` 内の以下の記述を変更する。
```
KIBANA_HOST=127.0.0.1:5601
```
Windowsの場合には、`templates/kibana/import.bat` を実行する前に、コマンドラインで以下を実行する。
```
set KIBANA_HOST=127.0.0.1:5601
```

## 4. CSVデータ出力
`get-result.sh` を実行することで、Elasticsearchに投入した結果からCSVデータを作ることができる。

ファイル中、ElasticsearchのIPアドレス（以下の127.0.0.1部分）を設定する。
```
curl -s -o aggs-result.json '127.0.0.1:9200/evaluation_result/_search' ...
```

以下の通り実行することで、結果は`aggs-result.csv` として出力される。
```
sh get-result.sh
```

## 各種ファイルの説明

![Alt text](image.png)

### 1. `query.template`
mkdocs.pyツールで必要なGitHubレポジトリにあるファイル。[query.template](query.template)
* https://github.com/togoannotator/ta/blob/elasticsearch/ranking_evaluation/検索精度評価/query.template

### 2. `input-file.tsv`
以下の列を持つmkdocs.pyの入力TSV形式ファイル
1. 検索キーワード
1. 辞書（Elasticsearchに登録されている辞書の呼称（以下のいずれかのみ対応））
    - cyanobacteria
    - ecoli
    - lab
    - bacteria
    - univ
1. match（"cs" 固定）
1. count（以降の結果セットの数）
1. 結果1
1. 結果1_ID
1. 結果1_検索順位  
(略)
1. 結果n
1. 結果n_ID
1. 結果n_検索順位

### 3. `input/query.json`
evaluatorの入力になるクエリデータ。評価したいクエリを記述するファイル。
`.env`の環境変数XXXで指定されたディレクトリパス配下の `input/query.json`が利用される

### 4. `input/docs.ndjson`
evaluatorの入力になる正解データ。`.env`の環境変数XXXで指定されたディレクトリパス配下の `input/docs.ndjson`が利用される

正解データのIDおよびrateを記述するフォーマットは下記の通り    
```
cat docs.ndjson
{"_id": "1", "rating":1}
{"_id": "2", "rating":2}
{"_id": "3", "rating":3}
```
ndjsonの他にcsv, tsvをサポートしている。

### 5. `output/result-YYYYMMDD.json`
APIレスポンスのJSON。RankingEvaluation APIの出力結果ファイル。YYYYMMDDは、出力した日付。`.env`で指定されたパスの`output` フォルダに結果を出力される。

### 6. `output/result-YYYYMMDD.csv`
サマリー結果のCSV。evaluatorの出力の１つでクエリごとに、各スコアを列挙したサマリ情報。indexerの入力ファイルになる。`.env`で指定されたパスの`output` フォルダに結果を出力される。

### 7. index template :TODO
index templateが事前に読み込まれる。

### 8. `aggs-result.csv`
最終結果ファイル。出力されるデータの意味は以下になる。
1. クエリ番号（inputディレクトリのディレクトリ番号と対応する）
1. Precisionスコア
1. Recallスコア
1. nDCGスコア

## 環境変数
|環境変数|説明|初期値|注釈|
|:---|:---|:---|:---|
|`TARGET_INDEX`|Evaluatorがクエリ検証を行う対象となるインデックス名|my_index||
|`ES_HOST`|Evaluatorがクエリ検証を行うElasticsearchのIPアドレス|127.0.0.1|EVAL_HOSTの可能性あり|
|`ES_UESR`| (※Security機能を有効にしている場合のみ)EvaluatorがElasticsearchにログインするためのユーザ名|elastic|EVAL_USERの可能性あり|
|`ES_PASSWORD`|(※Security機能を有効にしている場合のみ)EvaluatorがElasticsearchにログインするためのパスワード|changeme|EVAL_PASSWORDの可能性あり|
|`QUERY_NAME_PATTERN`|inputディレクトリ内で使用するクエリファイル名のパターン|"sample_query*"||
|FILE_TYPE|正解データのファイル形式|ndjson||
|TEMPLATE_NAME|Indexerが結果を投入するインデックスのテンプレート名|'evaluation_result'||
|TEMPLATE_DIR|Indexerが結果を投入するインデックスのテンプレートファイル|'/work/templates/elasticsearch/evaluation_result.json'||
|RESULT_INDEX|Indexerが結果を投入するインデックス名|evaluation_result||
|`RESULT_HOST`|Indexerが結果を投入するElasticsearchのIPアドレス|127.0.0.1||
|`INDEXER_USER`|(※Security機能を有効にしている場合のみ)IndexerがElasticsearchにログインするためのユーザ名|elastic||
|`INDEXER_PASSWORD`|(※Security機能を有効にしている場合のみ)IndexerがElasticsearchにログインするためのパスワード|changeme||

* `ENV_VARIABLE_NAME`は環境に合わせて変更する必要があるもの。それ以外は通常は変更しなくてよいもの
* .envに記載されたその他の環境変数は変更しない（Do NOT change settings below）

以下.envの設定例（`example/docker/.env`参照）
```
# Evaluator
TARGET_INDEX=my_index
EVAL_HOST=127.0.0.1
EVAL_USER=elastic
EVAL_PASSWORD=changeme
QUERY_NAME_PATTERN="sample_query*"
FILE_TYPE=ndjson

# Indexer
TEMPLATE_NAME='evaluation_result'
TEMPLATE_DIR='/work/templates/elasticsearch/evaluation_result.json'
RESULT_INDEX=evaluation_result
RESULT_HOST=127.0.0.1
INDEXER_USER=elastic
INDEXER_PASSWORD=changeme

```

## docker-composeの構成
### (1) evaluator
`.env`で指定されたパスの`input` フォルダにあるクエリデータ`query.json`および正解データ`docs.ndjson`を読み込み、`.env`で指定されたパスの`output` フォルダに結果を出力する。正解データの形式は ndjson, csv, tsvをサポートしている。

出力結果はAPIレスポンスのJSONと、サマリ結果のCSVファイルが出力される。

### (2) indexer
evaluatorが出力したサマリ結果のCSVを読み込み、Elasticsearchにインデキシングする。このとき、index templateが事前に読み込まれる。


### (参考） DockerComposeを使用しないで、コマンドラインからクエリ評価を実施する場合の手順

`src/evaluator`、`src/indexer` 配下からコマンドで実行が可能

### コマンド例
（`sample/docker/.env` に記述された、`EVALUATOR_CMD` などを参考にすると良い）  
※ `.env` は不要。全て起動引数に含むため。
```
python evaluation.py ${TARGET_INDEX} --host ${ES_HOST} -u ${ES_USER} -i ${INPUT_DIR} --http_proxy ${HTTP_PROXY} --https_proxy ${HTTPS_PROXY} -p ${ES_PASSWORD}
```