# TogoAnnotatorのDDBJ査定業務利用マニュアル(案)

## 使い方

### 1. 査定業務端末からTogoAnnotatorを実行する
*TODO:どの環境でどのように査定しているからヒアリングTrad関係者全員にヒアリングをLeeさんに確認してもらう*
* スパコン上にMSSユーザからscpアップロードされてきたファイルを査定業務環境にコピーする？
* 小菅さん作ann2table.plでannファイルからtable（TSV)形式に変換して査定？
*TODO:実行する方法を決めて記載する*

* 案A
ann2table.plにtogoannotatorの実行を組み込んで、結果も表示できるようにする

* 案B
スパコン上にscpアップロードされてきたannファイルを入力として、自動でta_result.tsvを生成する
```
curl -XPOST https//ta.ddbj.nig.ac.jp/genes -d @../../xxx.ann  |jq -r '...' > ta_result.tsv
```

### 2. 結果をXXXに利用する
*TODO:結果をどのように利用するかLeeさんと相談する*

ta_result.tsvの形式についてフィードバックをもらう

### 3. WL/BL/...の反映する
*TODO:仕方の低コスト化*
ann2table変換出力拡張ファイル or ta_result.tsvのT/F判定など編集差分を取り込む？

https://docs.google.com/spreadsheets/d/1pQ6HvvnbdLtQoGd6yquQc7WEmvFf9lAOXeps6HFC8Oc/edit#gid=0