【TogoAnnotatorアプリ環境構築・辞書データロード手順】

※いずれも、Linux上で一般ユーザによって実施することを前提としています
　docker / docker-compose コマンドの先頭に sudo を付けていますが、
　他OS環境またはdockerコマンドが実行可能なユーザで実施の際は、sudoを外してください。

■コンテナ化前のnginx, togoannotatorプロセスの停止手順
　コンテナ化する前のnginxやTogoAnnotatorアプリがホスト上で動作している
　場合に、停止する手順。
　※最初からコンテナで環境構築する場合はスキップする

1. nginx 停止手順
　　サービスの停止と自動起動の無効化を行う
　　　sudo systemctl status nginx
　　　sudo systemctl stop nginx
　　　sudo systemctl disable nginx
　　　sudo systemctl status nginx

　　以下の2行が確認できればOK
　　（1行目＝service; disabledとなっていること／2行目＝inactiveとなっていること）
　　　   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
　　　   Active: inactive (dead)

2. TogoAnnotator 停止手順
　　一般ユーザで構わないので、以下のコマンドで停止する
　　　hypnotoad -s /opt/services/ta/WebService/annotation2.pl

　　→以下が出力されることを確認する
　　　Stopping Hypnotoad server xxxx gracefully.
　　
　　　※実行中プロセスと停止コマンドを実行したユーザが異なるなどの場合、
　　　　以下のようなメッセージが出るが、停止すれば問題ない
　　　Hypnotoad server not running.

　　確認
　　　sudo ss -nap | grep tcp | grep LISTEN
　　　→5100ポートでLISTENしているプロセスが無ければOK


■環境クリーンアップ手順
　バージョンアップや環境の再構築などを行う場合は、構築前に既存環境を削除する。

0. 前提
　　a. dockerコマンドによりコンテナが停止済みである

1. docker コンテナの削除
　　a. 以下のコマンドでElasticsearch、Kibana、ta、nginxと名の付くコンテナを削除する
　　　sudo docker rm <コンテナ名>
　　
　　b. コンテナ一覧を出力し、削除されたことを確認する
　　　sudo docker ps -a

2. docker イメージの削除
　　a. 以下のコマンドでElasticsearch、Kibana、ta、nginxと名の付くイメージを削除する
　　　sudo docker rmi <イメージ名>:<TAG>
　　　or
　　　sudo docker rmi <イメージID>
　　
　　b. イメージ一覧を出力し、削除されていることを確認する
　　　sudo docker images

3. docker ネットワークの削除
　　a. 以下のコマンドでesnetと名の付くイメージを削除する
　　　sudo docker network rm <ネットワーク名>
　　　or
　　　sudo docker network rm <ネットワークID>
　　
　　b. Dockerネットワークの一覧を出力し、削除されていることを確認する
　　　sudo docker network list

4, ディレクトリの削除
　　Githubのリポジトリからコピーしてきたディレクトリを削除する


■プロキシ環境下で実行するための準備
　※実行するホストからインターネットへのアクセスにプロキシが不要な場合は
　　本項目はスキップしてください。
　※既に実施済みであればスキップしてください
　
1. ${HOME}/.docker ディレクトリが存在しない場合は作成する
　※既にディレクトリがd存在する場合は 2. に進む
　　mkdir ${HOME}/.docker

2. ${HOME}/.docker/config.json を作成する
　　vi ${HOME}/.docker/config.json

　以下の内容を記述し、保存・終了する。
　※(proxy-host), (proxy-port)は、ネットワーク管理者から指示されている
　　プロキシサーバのホスト名とポート番号で読み替えること
----
{
    "credsStore" : "desktop",
    "proxies" : {
        "default" : {
            "httpProxy" : "http://(proxy-host):(proxy-port)",
            "httpsProxy" : "http://(proxy-host):(proxy-port)"
        }
    },
    "stackOrchestrator":"swarm"
}
----


■コンテナ構築手順
　※任意のディレクトリを起点とした相対パスでの作業手順としている

1. 作業用ディレクトリを作成する
　　mkdir togoannotator

2. githubからcloneしたtaディレクトリをtogoannotatorディレクトリ下に配置する

3. ディレクトリを移動する
　　cd togoannotator/ta/app

4. nginx起動に必要なディレクトリを作成する
　　mkdir nginx/logs

5. TogoAnnotator起動に必要なディレクトリとログファイルを作成する
　　mkdir log
　　touch log/production.log

6. Elasticsearchに必要なディレクトリを作成する
　　mkdir esdata
　　mkdir es/share/log
　　chmod 777 esdata
　　chmod 777 es/share/log

7. Kibanaに必要なディレクトリとログファイルを作成する
　　mkdir kibana
　　touch kibana/kibana.log
　　chmod 777 kibana/kibana.log

8. Docker composeでTogoAnnotatorと辞書データローダーのコンテナをビルドする
　　以下のコマンドを実行する
　　　sudo docker-compose build

　　注)Windows版、macOS版のDocker Desktopを利用する場合は、FILE SHARINGの設定を行う必要がある。
　　　　DockerのSettings画面からResources > FILE SHARINGを開き、
　　　　ホスト側のディレクトリ、ファイルパスを登録する。

9. Docker composeでコンテナを起動する
　　以下のコマンドを実行する
　　　sudo docker-compose up -d


■辞書データロード手順

1. Docker composeのコンテナ起動時の投入
　　辞書データローダー（load_tool）をコンテナ化したため、
　　Docker composeの起動時に、Elasticsearchコンテナの起動を待って
　　自動的に辞書データのロードを行う。

2. 辞書データの再投入（ファイル名、インデックス名に変更がない場合）
　　Docker composeで、load_tool だけを再実行して、辞書の再投入が可能。
　　以下のコマンドを実行する。
　　　sudo docker-compose restart load_tool

　　※注意：それまでにElasticsearchに投入している辞書データはクリアされます

3. 辞書データロード結果の確認
　　起動した load_tool コンテナのコンソールログを見ることで、辞書データロード結果を確認する。
　　　sudo docker logs -f load_tool
　　
　　以下のログが出ている場合は、Elasticsearchが起動完了する前の状態
　　------------------------------------------------------------
　　Waiting for elasticsearch...
　　------------------------------------------------------------
　　※この状態が長く続いている場合は、Elasticsearchの起動に失敗している可能性があるため、
　　　環境や設定内容の確認を行ってください
　　
　　辞書データロードが完了すると、Elasticsearchのインデックス状態を表示するログが出る。
　　------------------------------------------------------------
　　[2020-10-21 03:04:41] Elasticsearch index確認開始
　　health status index uuid pri rep docs.count docs.deleted store.size pri.store.size
　　：
　　------------------------------------------------------------
　　ここで、投入対象のインデックスが存在し、件数が正しいことを確認する。

4. 投入対象辞書の追加・変更・削除
　　投入対象辞書の追加・変更・削除があった場合は、スクリプトを修正する必要がある。

　(1) 事前に用意するファイル／情報
　　a. 投入対象辞書データ（追加・変更の場合）
　　　→app/dictionary/es_data ディレクトリの中に置く

　　b. 投入先Elasticsearchインデックス名
　　　→TogoAnnotatorアプリがクエリを実行するインデックス名
　　　　(tm_ で始まる名前になっている想定)

　(2) スクリプトの修正
　　ta/appディレクトリで、以下のコマンドを実行しファイルを開く。
　　　vi load_tool/bin/data_load.sh

　　以下のログ出力処理の後にあるpython3.6実行コマンドを追加・変更・削除する。
　　75行目：
　　------------------------------------------------------------
　　logger "データロード処理開始" ${LOG_FILE}
　　------------------------------------------------------------

　　１つの辞書データファイルを投入するコマンドの形式は以下
　　【～】部分を、変更内容に合わせて置換える。
　　------------------------------------------------------------
　　logger "--- 【辞書名】 ---" ${LOG_FILE}
　　python3.6 -u pipeline_available_load_dict4es_ta.py --file ${ES_DATA}/【投入対象辞書データファイル名】 --index 【投入先インデックス名】 | tee -a ${LOG_FILE}
　　------------------------------------------------------------

　(3) 辞書データローダーの再ビルド・実行
　　(2)でスクリプトファイルの修正を行った場合は、辞書データローダーコンテナの再ビルドを行う。
　　ta/appディレクトリで以下のコマンドを実行する。
　　　sudo docker-compose build load_tool
　　
　　load_toolコンテナを再作成することでElasticsearchの辞書データを再ロードする。
　　　sudo docker-compose up load_tool     # フォアグラウンド実行の場合
　　　sudo docker-compose up -d load_tool  # バックグラウンド実行の場合
　　
　　※上記手順で正常に辞書データがロードされない場合は、docker-composeで全体を再起動する。
　　　（注意：一時的にサービスが停止します）
　　　　sudo docker-compose down
　　　　sudo docker-compose up -d

以上
