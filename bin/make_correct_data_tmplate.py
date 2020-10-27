import requests
import json
import argparse
import hashlib

class CorrectDataTemplate(object):
    def __init__(self, query, dictionary):
        #query = "Hog protein"
        self.dictionary = dictionary
        url = "https://togoannotator.dbcls.jp/gene?query=" + query + "&dictionary=" + dictionary + "&limit=10"

        headers = {"content-type": "application/json"}
        r = requests.get(url, headers=headers)
        data = r.json()
        #print(json.dumps(data, indent=4))
        self.output(data)

    def concat_md5(self, text1, text2, query_type):
        if query_type.endswith("_before"):
            return "{0}{1}{2}".format(hashlib.md5(text1.encode()).hexdigest(), hashlib.md5(text2.encode()).hexdigest(),
                                      query_type)
        else:
            return "{0}{1}".format(hashlib.md5(text1.encode()).hexdigest(), query_type)
    def output(self,data):
         #検索キーワード    辞書    結果1   結果1_ID    結果1_検索順位  結果2   結果2_ID    結果2_検索順位, ...
         #j = json.loads(data)
         #print(json.dumps(data, indent=4))
         hits = len(data['result_array'])
         o = [ data['query'], self.dictionary, data['match'], str(hits)]
         for item in data['result_array']:
             o.append(item)
             o.append(self.concat_md5(item,"", "term_after"))
             o.append("")

         #print("\t".join(data['result_array']))
         print("\t".join(o))
         

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-q", type=str)
    parser.add_argument("-d", type=str)
    args = parser.parse_args()

    CorrectDataTemplate(args.q, args.d)
    #connector.output(args.file)
