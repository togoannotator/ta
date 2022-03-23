#!/usr/bin/env python
# TogoAnnotatorで利用するAnnotation GuidelineのコードやメッセージをCSVからJSON形式にする。
# Googleスプレッドシートの"TogoAnnotatorにおけるタンパク質命名ガイドライン対応状況"にある、シート10をCSVとして取得したものを入力とする。
# getJsonFromGuideline.py > guidelines.json

import csv
import json

data = dict()

with open('TogoAnnot_Guidelines.csv') as f:
    reader = csv.reader(f)
    first = True
    for row in reader:
#        print(row)
        if first:
            header = row
            first = False
        else:
            data[row[0]] = dict(zip(header,row))

print(json.dumps(data, ensure_ascii=False, indent=2))