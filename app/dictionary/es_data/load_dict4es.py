#!/usr/bin/env python
from elasticsearch import Elasticsearch
from elasticsearch import helpers
import hashlib
import re
import argparse

# tsvのデータを加工してElasticsearchに投入するクラス
class TsvElasticsearchConnector(object):
    def __init__(self, host, index):
        self.es_client = Elasticsearch(host)
        self.queue = []
        self.index = index
        self.doc_type = "doc"
        self.query_types = ["term_after", "term_before", "mlt_after", "mlt_before"]
        self.both_ends_space = re.compile("^\s*|\s*$")
        self.both_ends_double_quote = re.compile("^\"\s*|\s*\"$")    
        self.double_quote_pattern = re.compile("^\s*|\s*$")
        self.symbols = re.compile("[\-/,:\+\(\)]")
        self.spaces = re.compile("\s+")
        self.putative_spaces = re.compile("^putative\s+", re.IGNORECASE)
        self.probable_spaces = re.compile("^probable\s+", re.IGNORECASE)
        self.possible_spaces = re.compile("^possible\s+", re.IGNORECASE)

        #b4name置換用定義
        self.putative_symbols = re.compile("^putative[\-/,:\+\(\)]", re.IGNORECASE)
        self.probable_symbols = re.compile("^probable[\-/,:\+\(\)]", re.IGNORECASE)
        self.possible_symbols = re.compile("^possible[\-/,:\+\(\)]", re.IGNORECASE)

    # ハッシュ値の計算処理
    # 移行前の辞書のキーはquery_type毎に異なるため、ハッシュの作り方もquery_typeで場合分けをした
    def concat_md5(self, text1, text2, query_type):
        if query_type.endswith("_before"):
            return "{0}{1}{2}".format(hashlib.md5(text1.encode()).hexdigest(), hashlib.md5(text2.encode()).hexdigest(),
                                      query_type)
        else:
            return "{0}{1}".format(hashlib.md5(text1.encode()).hexdigest(), query_type)

    def bulk_insert(self):
        helpers.bulk(self.es_client, self.queue, stats_only=True, raise_on_error=False)
        self.queue = []

    # データの事前加工処理
    # 今後各query_type、field毎に異なる加工要件が発生する可能性があるため、メソッドの共通化は行わない
    def convert_basic(self, text):
        text = re.sub(self.both_ends_space, "", text)
        text = re.sub(self.both_ends_double_quote, "", text)
        text = re.sub(self.putative_spaces, "", text)
        text = re.sub(self.probable_spaces, "", text)
        text = re.sub(self.possible_spaces, "", text)
        return text

    def convert_b4_to_b4source(self, text):
        text = re.sub(self.both_ends_space, "", text)
        text = re.sub(self.both_ends_double_quote, "", text)
        text = re.sub(self.putative_spaces, "", text)
        text = re.sub(self.probable_spaces, "", text)
        text = re.sub(self.possible_spaces, "", text)
        text = re.sub(self.putative_symbols, "", text)
        text = re.sub(self.probable_symbols, "", text)
        text = re.sub(self.possible_symbols, "", text)
        return text

    def convert_full(self, text):
        text = re.sub(self.both_ends_space, "", text)
        text = re.sub(self.both_ends_double_quote, "", text)
        text = re.sub(self.putative_spaces, "", text)
        text = re.sub(self.probable_spaces, "", text)
        text = re.sub(self.possible_spaces, "", text)
        text = text.lower()
        text = re.sub(self.symbols, " ", text)
        text = re.sub(self.spaces, " ", text)
        text = re.sub(self.both_ends_space, "", text)
        return text

    def convert_b4_to_lcb4(self, text):
        text = re.sub(self.both_ends_space, "", text)
        text = re.sub(self.both_ends_double_quote, "", text)
        text = text.lower()
        text = re.sub(self.symbols, " ", text)
        text = re.sub(self.both_ends_space, "", text)
        text = re.sub(self.spaces, " ", text)
        text = re.sub(self.putative_spaces, "", text)
        text = re.sub(self.probable_spaces, "", text)
        text = re.sub(self.possible_spaces, "", text)
        return text

    # ドキュメント投入処理
    # 100MBまでしかbulk投入はできないため、bulkを500件ごとに区切って投入する
    def throw_tsv(self, file_path):
        with open(file_path, encoding="utf-8") as f:
            i = 0
            for index, line in enumerate(f):
                i += 1
                self.queue.extend(self.convert_bulk(line))
                if index % 500 == 0:
                    self.bulk_insert()
                    print("bulk {0}".format(i))

            self.bulk_insert()
            print("bulk {0}".format(i))

    # ドキュメント生成処理
    def convert_bulk(self, line):
        elements = line.replace("\n", "").split("\t")
        actions = []
        for query_type in self.query_types:
            if query_type.endswith("_after"):
                converted_name = self.convert_full(elements[4])
                actions.append(
                        {'_op_type': "create", "_index": self.index, "_type": self.doc_type,
                         "_id": self.concat_md5(converted_name, "", query_type),
                         "_source": {"query_type": query_type, "name": self.convert_basic(elements[4]), "normalized_name": self.convert_basic(elements[4])}
                         })
            elif query_type.endswith("_before"):
                converted_name = self.convert_basic(elements[4])
                converted_normalized_name = self.convert_b4_to_lcb4(elements[5])
                actions.append(
                        {'_op_type': "index", "_index": self.index, "_type": self.doc_type,
                         "_id": self.concat_md5(converted_name, converted_normalized_name, query_type),
                         "_source": {"query_type": query_type, "name": self.convert_basic(elements[4]), "normalized_name": self.convert_b4_to_b4source(elements[5])}
                         })
        return actions

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", type=str)
    parser.add_argument("--index", type=str)
    args = parser.parse_args()

    connector = TsvElasticsearchConnector("localhost:19200", args.index)
    connector.throw_tsv(args.file)
