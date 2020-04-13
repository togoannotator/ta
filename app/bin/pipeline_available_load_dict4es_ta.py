#!/usr/bin/env python
from elasticsearch import Elasticsearch
from elasticsearch import helpers
import hashlib
import re
import argparse
import regex
import unicodedata
import json
import abc_en
import check_freq
import check_abbreviation
import check_chemical_symbols
#import check_std_sci_abb # pipelineで実装済み
import check_common_modifiers
from distutils.command.check import check
from cgitb import text

# tsvのデータを加工してElasticsearchに投入するクラス
class TsvElasticsearchConnector(object):
    def __init__(self, host, index):
        self.es_client = Elasticsearch(host)
        self.queue = []
        self.index = index
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

        self.diacritics = regex.compile(r"\p{M}")
        self.prime = regex.compile(r"\b\w+[\s-]prime\b")
    # ハッシュ値の計算処理
    # 移行前の辞書のキーはquery_type毎に異なるため、ハッシュの作り方もquery_typeで場合分けをした
    def concat_md5(self, text1, text2, query_type):
        if query_type.endswith("_before"):
            return "{0}{1}{2}".format(hashlib.md5(text1.encode()).hexdigest(), hashlib.md5(text2.encode()).hexdigest(),
                                      query_type)
        else:
            return "{0}{1}".format(hashlib.md5(text1.encode()).hexdigest(), query_type)

    def bulk_insert(self):
        #helpers.bulk(self.es_client, self.queue, stats_only=True, raise_on_error=False)
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
    
    def check_american_spelling(self, text): # PN001
        ba = abc_en.b2a(text)
        return ba == text

    def check_diacritics(self, text): # PN003 マッチしなければ加点
        return not self.diacritics.search(unicodedata.normalize("NFD", text))
    def check_prime(self, text): # PN011 マッチしなければ加点
        return not self.prime.search(text)

    def eval_guidelines(self, text):
        guideline = {}
        guideline_compliance_list = []
        guideline_noncompliance_list = []

        if self.check_american_spelling(text):
            guideline["PN001"] = "1"
            guideline_compliance_list.append("PN001")
        else:
            guideline_noncompliance_list.append("PN001")

        if self.check_diacritics(text):
            guideline["PN003"] = "1"
            guideline_compliance_list.append("PN003")
        else:
            guideline_noncompliance_list.append("PN003")

        if not check_freq.freqword_is_in(text): # 頻出語が含まれていなければガイドラインにマッチ
            guideline["PN005"] = "1"
            guideline_compliance_list.append("PN005")
        else:
            guideline_noncompliance_list.append("PN005")

        if not check_abbreviation.check_word_is_abbreviation(text): # 略語でなければガイドラインにマッチ
            guideline["PN007"] = "1"
            guideline_compliance_list.append("PN007")
        else:
            guideline_noncompliance_list.append("PN007")

        if self.check_prime(text): # プライムシンボルがない場合は加点
            guideline["PN011"] = "1"
            guideline_compliance_list.append("PN011")
        else:
            guideline_noncompliance_list.append("PN011")

        if check_chemical_symbols.text_contains_symbols(text): # 含んでいたら加点
            guideline["PN012"] = "1"
            guideline_compliance_list.append("PN012")
        else:
            guideline_noncompliance_list.append("PN012")

#        if not check_std_sci_abb.text_contains_std_sci_abb(text): # 含んでいたら非遵守 <- pipelineで実装済み
#            guideline["PN013"] = "1"
#            guideline_compliance_list.append("PN013")
#        else:
#            guideline_noncompliance_list("PN013")

        if check_common_modifiers.text_has_hyphen_b4_cm_or_others(text): # Common Modifiersがあれば、その直前はハイフンが必要
            guideline["PN016"] = "1"
            guideline_compliance_list.append("PN016")
        else:
            guideline_noncompliance_list.append("PN016")

        guideline["guideline_compliance_list"] = guideline_compliance_list
        guideline["guideline_noncompliance_list"] = guideline_noncompliance_list
        return guideline
    
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
        guidelines = self.eval_guidelines(elements[5])
        print(guidelines)
        actions = []
        for query_type in self.query_types:
            if query_type.endswith("_after"):
                converted_name = self.convert_full(elements[4])
                actions.append(
                        {'_op_type': "create", "_index": self.index, "pipeline": "judge-guideline-compliance",
                         "_id": self.concat_md5(converted_name, "", query_type),
                         "_source": dict({"query_type": query_type, "name": self.convert_basic(elements[4]), "normalized_name": self.convert_basic(elements[4])}, **guidelines)
                         })
            elif query_type.endswith("_before"):
                converted_name = self.convert_basic(elements[4])
                converted_normalized_name = self.convert_b4_to_lcb4(elements[5])
                actions.append(
                        {'_op_type': "index", "_index": self.index, "pipeline": "judge-guideline-compliance",
                         "_id": self.concat_md5(converted_name, converted_normalized_name, query_type),
                         "_source": dict({"query_type": query_type, "name": self.convert_basic(elements[4]), "normalized_name": self.convert_b4_to_b4source(elements[5])}, **guidelines)
                         })
        return actions

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", type=str)
    parser.add_argument("--index", type=str)
    args = parser.parse_args()

    connector = TsvElasticsearchConnector("localhost:9200", args.index)
    connector.throw_tsv(args.file)
