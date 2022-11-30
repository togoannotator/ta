# dict_universal_20201006.txt に李さんがキュレーションしたデータを反映させるためのスクリプト
lee_dic = dict()
with open("data/lee_curated_for_update.txt", "rt") as l:
    for line in l:
        values = line.rstrip().split('\t')
        if len(values) == 2:
            lee_dic[values[1]] = values[0]
#            print(values)
with open("data/dict_universal_20201006.txt", "rt") as f:
    for line in f:
        values = line.rstrip().split('\t')
        try:
            del(lee_dic[values[5]])
        except:
            continue

for k in lee_dic:
    print("\t".join((k,lee_dic[k])))