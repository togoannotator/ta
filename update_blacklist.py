import re
with open("app/dictionary/ref_data/lee_curated_for_black.txt", "rt") as f:
    for line in f:
        values = line.rstrip().split('\t')
        if values[1] == '?':
            continue
        q = re.sub('  +', " ", values[0]).strip()
        b = re.sub('  +', " ", values[1]).strip()
        if q == b:
            print(q)
        else:
            print(q + '\t' + b)
#            print( (re.sub('  +', " ", q.replace(b, ""))).strip() )