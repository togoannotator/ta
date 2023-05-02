# TogoAnnotatorを用いた品質評価

Leeさんに選別していただいたアノテーションに課題のあるゲノム
[TogoAnn_品質評価候補](https://docs.google.com/spreadsheets/d/1fJqROTFscUT9W6fQGgbUJ98foM3aB1miwxT1-zA1xPo/edit?ts=5f6d39f3#gid=926990198)

## 準備

### RDFからproduct nameのユニークリストを作成

以下、MacOSX上での作業
```
cd ranking_evaluation/
curl -o http://togows.org/entry/nucleotide/CP000776.1.ttl
# cat CP000776.1.ttl |grep insdc:product |cut -f3 |uniq   |pbcopy 
# pbpaste >../ranking_evaluation/CP000776.1.txt
grep CP000776.1.ttl insdc:product |cut -f3 |uniq  > CP000776.1.txt
```

### 正解データ作業シートのテンプレート作成

bin/make_correct_data_tmplate.pyを繰り返し呼び出す、t.shスクリプトを実行しテンプレートファイルを作成する


```
bash t.sh |tee CP000776.1.raw
```

* [2022-05-01] TogoAnnotatorのat097環境に対して実行する場合、make_correct_data_tmplate.py内のアクセスURLを変更した

```
bash t.sh |tee CP000776.1.raw-20230501
```

補足: make_correct_data_tmplate.py実行例

```
[tf@at097 ranking_evaluation]$ python ../bin/make_correct_data_tmplate.py -q "transcriptional regulator family" -d "univ"
transcriptional regulator family	univ	cs	15	DeoR family transcriptional regulator	216a1496bd895c63795c88e17f016194mlt_after	
transcriptional regulator family	univ	cs	15	transcriptional regulator, Fis family	af81c341afb6a3b5c868fd67ee293fdcmlt_after	
transcriptional regulator family	univ	cs	15	LytR family transcriptional regulator	523ebba0c23a87c357cb96f0a5d39df4mlt_after	
transcriptional regulator family	univ	cs	15	LysR family transcriptional regulator	599cdfae4c275dc147f5167bc66454e3mlt_after	
transcriptional regulator family	univ	cs	15	MltR family transcriptional regulator	6e0e1473f35ab75d3bf85a4c55831cb3mlt_after	
transcriptional regulator family	univ	cs	15	TetR family transcriptional regulator	d2131a4303cefc3209a259a707ca7f38mlt_after	
transcriptional regulator family	univ	cs	15	CRP/FNR family transcriptional regulator	219b09b459e19fce60fb41e480e019c9mlt_after	
transcriptional regulator family	univ	cs	15	AraC family transcriptional regulator	9fa0806b3f2b253175d3b885db0149e1mlt_after	
transcriptional regulator family	univ	cs	15	transcriptional regulator, AraC family	d53c8c83313fd806528a90697cea1c11mlt_after	
transcriptional regulator family	univ	cs	15	DeoR/GlpR family transcriptional regulator	65e5df6b7d8192663ca285385e310ae6mlt_after	
transcriptional regulator family	univ	cs	15	Cotranscriptional regulator FAM172A	ffe4dfd4d3524b16b64e6f19eb52b9ecmlt_after	
transcriptional regulator family	univ	cs	15	transcriptional regulator flp	ec1b3750ca8282c8a131e7ef4a889f43mlt_after	
transcriptional regulator family	univ	cs	15	transcriptional regulator FtrA	e8eef94e8cef9aee3af8636a4499bd00mlt_after	
transcriptional regulator family	univ	cs	15	LysR family transcriptional regulator PA0133	5adac2f8854432d962aad8d963e065a9mlt_after	
transcriptional regulator family	univ	cs	15	LysR family transcriptional regulator PA2877	54d889807b8eeacc04462d33bf562524mlt_after	
```

### 正解データ変換
Google spreadsheetの作業シートからcs行のみフィルターしてコピー＆ペースト、ファイル出力後に変換

```
pbpaste >x
ruby convert.rb > CP000776.1_2021-01-14.tsv
```

* [2022-05-02] convert.rb内でxファイル指定されていたので、yファイルに変更
```
egrep "  cs      " CP000776.1.raw-20230501  > y
ruby convert.rb  > CP000776.1_2023-05-02.tsv
