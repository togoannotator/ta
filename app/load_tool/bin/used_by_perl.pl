use warnings;
#use strict;
use open ":utf8";
use Fatal qw/open/;
use Inline Python;
 
 
__END__
__Python__
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
import check_colon_semicolon
import check_Delta
#import check_std_sci_abb # pipelineで実装済み
import check_common_modifiers
from distutils.command.check import check
from cgitb import text

# tsvのデータを加工してElasticsearchに投入するクラス
class TsvElasticsearchConnector(object):
    def __init__(self):
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
        self.greek = regex.compile(r"\b(?:\p{Greek}|Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega)\b") # マッチしなければ加点

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
    def check_greek(self, text): # PN027 マッチしなければ加点
        return not self.greek.search(text)

    def eval_guidelines(self, text):
        guideline = {}
        guideline_compliance_list = []
        guideline_noncompliance_list = []
        guideline_score_add = 0

        if self.check_american_spelling(text):
            guideline["guideline_PN001"] = 1
            guideline_compliance_list.append("PN001")
            guideline_score_add += guideline["guideline_PN001"]
        else:
            guideline_noncompliance_list.append("PN001")

        if self.check_diacritics(text):
            guideline["guideline_PN003"] = 1
            guideline_compliance_list.append("PN003")
            guideline_score_add += guideline["guideline_PN003"]
        else:
            guideline_noncompliance_list.append("PN003")

        if not check_freq.freqword_is_in(text): # 頻出語が含まれていなければガイドラインにマッチ
            guideline["guideline_PN005"] = 1
            guideline_compliance_list.append("PN005")
            guideline_score_add += guideline["guideline_PN005"]
        else:
            guideline_noncompliance_list.append("PN005")

        if not check_abbreviation.check_word_is_abbreviation(text): # 略語でなければガイドラインにマッチ
            guideline["guideline_PN007"] = 1
            guideline_compliance_list.append("PN007")
            guideline_score_add += guideline["guideline_PN007"]
        else:
            guideline_noncompliance_list.append("PN007")

        if self.check_prime(text): # プライムシンボルがない場合は加点
            guideline["guideline_PN011"] = 1
            guideline_compliance_list.append("PN011")
            guideline_score_add += guideline["guideline_PN011"]
        else:
            guideline_noncompliance_list.append("PN011")

        if not check_chemical_symbols.text_contains_symbols(text): # 含んでいなかったら加点
            guideline["guideline_PN012"] = 1
            guideline_compliance_list.append("PN012")
            guideline_score_add += guideline["guideline_PN012"]
        else:
            guideline_noncompliance_list.append("PN012")

#        if not check_std_sci_abb.text_contains_std_sci_abb(text): # 含んでいたら非遵守 <- pipelineで実装済み
#            guideline["guideline_PN013"] = 1
#            guideline_compliance_list.append("PN013")
#            guideline_score_add += guideline["guideline_PN013"]
#        else:
#            guideline_noncompliance_list("PN013")

        if check_common_modifiers.text_has_hyphen_b4_cm_or_others(text): # Common Modifiersがあれば、その直前はハイフンが必要
            guideline["guideline_PN016"] = 1
            guideline_compliance_list.append("PN016")
            guideline_score_add += guideline["guideline_PN016"]
        else:
            guideline_noncompliance_list.append("PN016")

        if not check_colon_semicolon.text_contains_col_semi(text):
            guideline["guideline_PN019"] = 1
            guideline_compliance_list.append("PN019")
            guideline_score_add += guideline["guideline_PN019"]
        else:
            guideline_noncompliance_list.append("PN019")

        if self.check_greek(text): # Greek letterの使い方が不適切でない限り加点
            guideline["guideline_PN027"] = 1
            guideline_compliance_list.append("PN027")
            guideline_score_add += guideline["guideline_PN027"]
        else:
            guideline_noncompliance_list.append("PN027")

        if check_Delta.text_contains_Delta_steroid_fatty_acid(text):
            guideline["guideline_PN028"] = 1
            guideline_compliance_list.append("PN028")
            guideline_score_add += guideline["guideline_PN028"]
        else:
            guideline_noncompliance_list.append("PN028")
            
        guideline["guideline_compliance_list"] = guideline_compliance_list
        guideline["guideline_noncompliance_list"] = guideline_noncompliance_list
        guideline["guideline_score_add"] = guideline_score_add
        return guideline
    
if __name__ == "__main__":
    print('モジュール名：{}'.format(__name__))
