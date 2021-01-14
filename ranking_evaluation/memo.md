https://docs.google.com/spreadsheets/d/1fJqROTFscUT9W6fQGgbUJ98foM3aB1miwxT1-zA1xPo/edit?ts=5f6d39f3#gid=926990198


# cd ranking_evaluation/

# RDF取得
curl -o http://togows.org/entry/nucleotide/CP000776.1.ttl

# less CP000776.1.ttl |grep insdc:product |cut -f3 |uniq   |pbcopy 
# pbpaste >../ranking_evaluation/CP000776.1.txt

# product収集とユニークリスト作成 .txt
grep CP000776.1.ttl insdc:product |cut -f3 |uniq  > CP000776.1.txt

# 正解データ作業シートのテンプレート作成
# bash t.sh > ../ranking_evaluation/CP000776.1.raw
# python ../bin/make_correct_data_tmplate.py -q "transcriptional regulator family" -d "univ"

```
  1 #!/bin/bash
  2 DATA=`cat ../ranking_evaluation/CP000776.1.txt`
  3 while read line
  4 do
  5   echo $line
  6 /Users/tf/.anyenv/envs/pyenv/shims/python make_correct_data_tmplate.py -q "$line" -d "univ"
  7 done << FILE
  8 $DATA
  9 FILE
  ```

bash t.sh |tee CP000776.1.raw

# 正解データ変換
Google spreadsheetの作業シートからcs行のみフィルターしてコピー＆ペースト、ファイル出力後に変換
pbpaste >x
ruby convert.rb > CP000776.1_2021-01-14.tsv