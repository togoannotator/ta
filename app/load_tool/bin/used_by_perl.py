import sys
import hashlib
import re
#import argparse
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
#from distutils.command.check import check
#from cgitb import text

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

        self.pn002 = regex.compile(r"[a-z]{3,}ine$")
        self.pn004 = regex.compile(r"(?:repeats|domains)")
        self.pn013 = regex.compile(r"(?:deoxyribonucleic acid|complementary DNA|double-stranded DNA|single-stranded DNA|double-stranded RNA|messenger RNA|microRNA|Piwi-interacting RNA|small interfering RNA|small nuclear RNA|small nucleolar RNA|single-stranded RNA|transfer RNA|transfer-messenger RNA|ribosomal RNA|2'-deoxyadenosine 5'-monophosphate|deoxycytidine monophosphate|2'-deoxyguanosine 5'-monophosphate|deoxythymidine monophosphate|deoxyadenosine diphosphate|deoxycytidine diphosphate|deoxyguanosine diphosphate|deoxythymidine diphosphate|deoxyadenosine triphosphate|deoxycytidine triphosphate|deoxyguanosine triphosphate|deoxythymidine triphosphate|flavin adenine dinucleotide|flavin mononucleotide|nicotinamide adenine dinucleotide|nicotinamide adenine dinucleotide phosphate|ATP-binding cassette|major facilitator superfamily|resistance-nodulation-cell division|multidrug and toxic compound extrusion|small multidrug resistance|ribosomal RNA methyltransferase)")
        self.pn014 = regex.compile(r"\\")
        self.pn017 = regex.compile(r"\.$")
        self.pn018 = regex.compile(r",\s")
        self.pn020 = regex.compile(r"%")
        self.pn021 = regex.compile(r"@")
        self.pn022 = regex.compile(r"=")
        self.pn024 = regex.compile(r"\bM{1,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\b|\bM{0,4}(CM|CD|D|D?C{1,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\b|\bM{0,4}(CM|CD|D?C{0,3})(XC|XL|L|L?X{1,3})(IX|IV|V?I{0,3})\b|\bM{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V|V?I{1,3})\b/")
        self.pn026 = regex.compile(r"^[A-Z0-9]+ [A-Z0-9 ]+$")
        self.pn029 = regex.compile(r"factor protein|enzyme protein|inhibitor protein|regulator protein|.+ase protein")
        self.pn030 = regex.compile(r".+ase enzyme")
        self.pn034 = regex.compile(r"COG\d{4}|KOG\d{4}|FOG\d{4}|GO:\d{7}|\d+\.-\.-\.-|\d+\.\d+\.-\.-|\d+\.\d+\.\d+\.-|\d+\.\d+\.\d+\.(n)?\d+|PF\d{5}")
        self.pn036 = regex.compile(r"\b(:?for|or|of|to|with|also known as|together with)\b")
        self.pn037 = regex.compile(r"cell surface|cell surface protein|conserved hypothetical|hypothetical conserved|identified by|identity to|involved in|implicated in|protein domain protein|protein of unknown function|protein hypothetical|protein protein|protein putative|putative putative|questionable protein|related to|signal peptide protein|similar to|surface antigen|surface protein|unknown protein|authentic point mutation|low quality protein|C term|C terminal|N term|N terminal|inactivated derivative|conserved uncharacterized|uncharacterized conserve")
        self.pn038 = regex.compile(r"antigen|CDS|conserved|cytoplasmic|deletion|dubious|doubtful|expressed|fragment|frame shift|frameshift|genome|homolog|interrupt|KDa|K Da|likely|locus|locus_tag|novel|ORF|partial|possible|potential|predicted|probable|pseudo|pseudogene|secreted|strongly|truncate|truncated|under|unique|unnamed|WGS|Xray|X-ray")
        self.pn048 = regex.compile(r"^(?i)(b|mult)ifunctional protein$")
        self.pn049 = regex.compile(r"\b(chain|component|type)\b")
        self.pn050 = regex.compile(r"\b(:inactive)\b")
        self.pn051 = regex.compile(r"(.+hypothetical protein|hypothetical protein.+|.+uncharacterized protein|uncharacterized protein.+)")

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

        if self.pn002.search(text):
            guideline_noncompliance_list.append("PN002")
        else:
            guideline["guideline_PN002"] = 1
            guideline_score_add += guideline["guideline_PN002"]
            guideline_compliance_list.append("PN002")

        if self.pn004.search(text):
            guideline_noncompliance_list.append("PN004")
        else:
            guideline["guideline_PN004"] = 1
            guideline_score_add += guideline["guideline_PN004"]
            guideline_compliance_list.append("PN004")

        if self.pn013.search(text):
            guideline_noncompliance_list.append("PN013")
        else:
            guideline["guideline_PN013"] = 1
            guideline_score_add += guideline["guideline_PN013"]
            guideline_compliance_list.append("PN013")

        if self.pn014.search(text):
            guideline_noncompliance_list.append("PN014")
        else:
            guideline["guideline_PN014"] = 1
            guideline_score_add += guideline["guideline_PN014"]
            guideline_compliance_list.append("PN014")

        if self.pn017.search(text):
            guideline_noncompliance_list.append("PN017")
        else:
            guideline["guideline_PN017"] = 1
            guideline_score_add += guideline["guideline_PN017"]
            guideline_compliance_list.append("PN017")

        if self.pn018.search(text):
            guideline_noncompliance_list.append("PN018")
        else:
            guideline["guideline_PN018"] = 1
            guideline_score_add += guideline["guideline_PN018"]
            guideline_compliance_list.append("PN018")

        if self.pn020.search(text):
            guideline_noncompliance_list.append("PN020")
        else:
            guideline["guideline_PN020"] = 1
            guideline_score_add += guideline["guideline_PN020"]
            guideline_compliance_list.append("PN020")

        if self.pn021.search(text):
            guideline_noncompliance_list.append("PN021")
        else:
            guideline["guideline_PN021"] = 1
            guideline_score_add += guideline["guideline_PN021"]
            guideline_compliance_list.append("PN021")

        if self.pn022.search(text):
            guideline_noncompliance_list.append("PN022")
        else:
            guideline["guideline_PN022"] = 1
            guideline_score_add += guideline["guideline_PN022"]
            guideline_compliance_list.append("PN022")

        if self.pn024.search(text):
            guideline_noncompliance_list.append("PN024")
        else:
            guideline["guideline_PN024"] = 1
            guideline_score_add += guideline["guideline_PN024"]
            guideline_compliance_list.append("PN024")

        if self.pn026.search(text):
            guideline_noncompliance_list.append("PN026")
        else:
            guideline["guideline_PN026"] = 1
            guideline_score_add += guideline["guideline_PN026"]
            guideline_compliance_list.append("PN026")

        if self.pn029.search(text):
            guideline_noncompliance_list.append("PN029")
        else:
            guideline["guideline_PN029"] = 1
            guideline_score_add += guideline["guideline_PN029"]
            guideline_compliance_list.append("PN029")

        if self.pn030.search(text):
            guideline_noncompliance_list.append("PN030")
        else:
            guideline["guideline_PN030"] = 1
            guideline_score_add += guideline["guideline_PN030"]
            guideline_compliance_list.append("PN030")

        if self.pn034.search(text):
            guideline_noncompliance_list.append("PN034")
        else:
            guideline["guideline_PN034"] = 1
            guideline_score_add += guideline["guideline_PN034"]
            guideline_compliance_list.append("PN034")

        if self.pn036.search(text):
            guideline_noncompliance_list.append("PN036")
        else:
            guideline["guideline_PN036"] = 1
            guideline_score_add += guideline["guideline_PN036"]
            guideline_compliance_list.append("PN036")

        if self.pn037.search(text):
            guideline_noncompliance_list.append("PN037")
        else:
            guideline["guideline_PN037"] = 1
            guideline_score_add += guideline["guideline_PN037"]
            guideline_compliance_list.append("PN037")

        if self.pn038.search(text):
            guideline_noncompliance_list.append("PN038")
        else:
            guideline["guideline_PN038"] = 1
            guideline_score_add += guideline["guideline_PN038"]
            guideline_compliance_list.append("PN038")

        if self.pn048.search(text):
            guideline_noncompliance_list.append("PN048")
        else:
            guideline["guideline_PN048"] = 1
            guideline_score_add += guideline["guideline_PN048"]
            guideline_compliance_list.append("PN048")

        if self.pn049.search(text):
            guideline_noncompliance_list.append("PN049")
        else:
            guideline["guideline_PN049"] = 1
            guideline_score_add += guideline["guideline_PN049"]
            guideline_compliance_list.append("PN049")

        if self.pn050.search(text):
            guideline_noncompliance_list.append("PN050")
        else:
            guideline["guideline_PN050"] = 1
            guideline_score_add += guideline["guideline_PN050"]
            guideline_compliance_list.append("PN050")

        if self.pn051.search(text):
            guideline_noncompliance_list.append("PN051")
        else:
            guideline["guideline_PN051"] = 1
            guideline_score_add += guideline["guideline_PN051"]
            guideline_compliance_list.append("PN051")


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
#    print('モジュール名：{}'.format(__name__))
    chk = TsvElasticsearchConnector()
    for line in sys.stdin:
        result = chk.eval_guidelines(line.strip())
        print(json.dumps(result))