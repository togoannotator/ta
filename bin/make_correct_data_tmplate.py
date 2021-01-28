import requests
import json
import argparse
import hashlib
import re
import regex

class CorrectDataTemplate(object):
    def __init__(self, query, dictionary):
        #query = "Hog protein"
        self.dictionary = dictionary
        self.queue = []
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
        self.greek = regex.compile(r"\b(?:\p{Greek}|Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega)\b") # マッチしなければ加点

        url = "https://togoannotator.dbcls.jp/gene?query=" + query + "&dictionary=" + dictionary + "&limit=10"

        headers = {"content-type": "application/json"}
        r = requests.get(url, headers=headers)
        data = r.json()
        #print(json.dumps(data, indent=4))
        self.output(data)
        
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

    def concat_md5(self, text1, text2, query_type):
        if query_type.endswith("_before"):
            return "{0}{1}{2}".format(hashlib.md5(text1.encode()).hexdigest(), hashlib.md5(text2.encode()).hexdigest(),
                                      query_type)
        else:
            return "{0}{1}".format(hashlib.md5(text1.encode()).hexdigest(), query_type)

    def name2term_after_id(self, text):
        converted_name = self.convert_full(text)
        return self.concat_md5(converted_name, "", "mlt_after")

    def output2(self,data):
         #検索キーワード    辞書    結果1   結果1_ID    結果1_検索順位  結果2   結果2_ID    結果2_検索順位, ...
         #j = json.loads(data)
         #print(json.dumps(data, indent=4))
         hits = len(data['result_array'])
         o = [ data['query'], self.dictionary, data['match'], str(hits)]
         for item in data['result_array']:
             o.append(item)
             o.append(self.concat_md5(item,"", "mlt_after"))
             o.append("")

         #print("\t".join(data['result_array']))
         print("\t".join(o))

    def output(self,data):
        hits = len(data['result_array'])
        o = [ data['query'], self.dictionary, data['match'], str(hits)]
        for item in data['result_array']:
            #print("\t".join(o + [item, self.concat_md5(item,"", "term_after"),""]))
            print("\t".join(o + [item, self.name2term_after_id(item),""]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-q", type=str)
    parser.add_argument("-d", type=str)
    args = parser.parse_args()

    CorrectDataTemplate(args.q, args.d)
