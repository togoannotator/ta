# Ranking Evaluationによるクエリ評価
## 1. 概要
Elasticsearch インデックスに対して Ranking Evaluation APIリクエストを発行し、評価値をファイル出力・Kibanaによる可視化をおこなう。各種設定値を `docker/.env` ファイルに記述し、docker-composeで実行する。

なお、ダッシュボード作成は docker-composeとは別途、shellスクリプトもしくはbatスクリプトを実行する構成となっている。

### モジュール構成
#### (1) evaluator
`.env`で指定されたパスの`input` フォルダにあるクエリデータ`query.json`および正解データ`docs.ndjson`を読み込み、`.env`で指定されたパスの`output` フォルダに結果を出力する。正解データの形式は ndjson, csv, tsvをサポートしている。

出力結果はAPIレスポンスのJSONと、サマリ結果のCSVファイルが出力される。

#### (2) indexer
evaluatorが出力したサマリ結果のCSVを読み込み、Elasticsearchにインデキシングする。このとき、index templateが事前に読み込まれる。


## 2. クエリデータと正解データの事前準備
inputフォルダ配下に、任意の名前のフォルダを作成し、その直下に次のファイルを作成する。詳細は `sample/input` 配下を参照。
### (1) クエリデータ
`query.json`として評価したいクエリを記述する

### (2) 正解データ
`docs.ndjson`として正解ドキュメントのIDおよびrateを記述する

docs.ndjsonのフォーマットは下記の通り    
```
{"_id": "1", "rating":1}
{"_id": "2", "rating":2}
{"_id": "3", "rating":3}
```


inputディレクトリ配下にクエリと正解データは、簡易ツール`mkdocs.py` を利用して、生成することができる。ツールは、Python3で動作する。

### mkdocs.pyによるクエリデータと正解データの生成
あらかじめ、同ディレクトリにquery.templateファイルを置き、以下のコマンドを実行する。

```
python3 mkdocs.py <input-file.tsv>
```

`input-file.tsv` は、TSV形式で以下の列を持つファイルに対応する。
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

※すでに出力されているデータは削除しない。同じ名前ならば上書きするが、変更されなかったファイルはそのまま残るので注意。

## 3. クエリ評価を実施する
### 3-1. DockerComposeを使用してクエリ評価を実施する

#### 3-1-1. .envの設定
`docker/.env`に対象インデックスやホストを記述する。

`.env`の設定例（`example/docker/.env`参照）
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

# Do NOT change settings below
(以下省略)
```

##### 環境に合わせて変更する必要があるもの：
- TARGET_INDEX
    - Evaluatorがクエリ検証を行う対象となるインデックス名
- ES_HOST
    - Evaluatorがクエリ検証を行うElasticsearchのIPアドレス
- ES_UESR
    - (※Security機能を有効にしている場合のみ)EvaluatorがElasticsearchにログインするためのユーザ名
- ES_PASSWORD
    - (※Security機能を有効にしている場合のみ)EvaluatorがElasticsearchにログインするためのパスワード
- QUERY_NAME_PATTERN
    - inputディレクトリ内で使用するクエリファイル名のパターン
- RESULT_HOST
    - Indexerが結果を投入するElasticsearchのIPアドレス
- INDEXER_USER
    - (※Security機能を有効にしている場合のみ)IndexerがElasticsearchにログインするためのユーザ名
- INDEXER_PASSWORD
    - (※Security機能を有効にしている場合のみ)IndexerがElasticsearchにログインするためのパスワード

##### 通常は変更しなくてよいもの：
- FILE_TYPE
    - 正解データのファイル形式
- TEMPLATE_NAME
    - Indexerが結果を投入するインデックスのテンプレート名
- TEMPLATE_DIR
    - Indexerが結果を投入するインデックスのテンプレートファイル
- RESULT_INDEX
    - Indexerが結果を投入するインデックス名

#### 3-1-2. コンテナをビルドする
```
docker-compose build
```

プロキシの指定が必要な場合は、以下のようにオプションを指定する。
```
docker-compose build --build-arg http_proxy=192.168.1.250:8080 --build-arg https_proxy=192.168.1.250:8080
```

#### 3-1-3. コンテナを立ち上げる
```
docker-compose up
```

#### 3-1-4. 出力された結果を確認する
出力はデフォルトで、`output`フォルダに出力される (`.env`で指定可能)

出力されるファイルは2種類ある。(YYYYMMDDは、出力した日付)
- result-YYYYMMDD.csv
    - クエリごとに、各スコアを列挙したサマリ情報
- result-YYYYMMDD.json
    - RankingEvaluation APIの出力結果


## 3-2. コマンドラインからクエリ評価を実施する
※DockerComposeを使用しないで、クエリ評価を実施する場合の手順

`src/evaluator`、`src/indexer` 配下からコマンドで実行が可能

### 3-2-1. コマンド例
（`sample/docker/.env` に記述された、`EVALUATOR_CMD` などを参考にすると良い）  
※ `.env` は不要。全て起動引数に含むため。
```
python evaluation.py ${TARGET_INDEX} --host ${ES_HOST} -u ${ES_USER} -i ${INPUT_DIR} --http_proxy ${HTTP_PROXY} --https_proxy ${HTTPS_PROXY} -p ${ES_PASSWORD}
```

## 4. ダッシュボードのインポート
`templates/kibana/import.bat` もしくは `templates/kibana/import.sh` を実行する。

この時、環境変数 `KIBANA_HOST` にKibanaのIPアドレスとポート番号を登録する必要がある。

### 4-1. 設定例
#### (1) Windows
`templates/kibana/import.bat` を実行する前に、コマンドラインで以下を実行する。
```
set KIBANA_HOST=127.0.0.1:5601
```

#### (2) Linux
`templates/kibana/import.sh` 内の以下の記述を変更する。
```
KIBANA_HOST=127.0.0.1:5601
```

## 5. CSVデータ出力
`get-result.sh` を実行することで、Elasticsearchに投入した結果からCSVデータを作ることができる。

ファイル中、ElasticsearchのIPアドレス（以下の127.0.0.1部分）を設定する。
```
curl -s -o aggs-result.json '127.0.0.1:9200/evaluation_result/_search' ...
```

実行は以下の通り行う。
```
sh get-result.sh
```

結果は `aggs-result.csv` として出力される。

出力されるデータの意味は以下になる。
1. クエリ番号（inputディレクトリのディレクトリ番号と対応する）
1. Precisionスコア
1. Recallスコア
1. nDCGスコア
