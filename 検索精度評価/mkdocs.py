import os
import sys

if len(sys.argv) < 2:
    print("USAGE: " + sys.argv[0] + " input-file")
    sys.exit(1)

infile = sys.argv[1]

# 辞書名からElasticsearchのインデックス名に変換するマップ
idxmap = {
    'cyanobacteria': 'tm_53a186f8c95c329d6bddd8bc3d3b4189',
    'ecoli': 'tm_f0a37107d9735025c81673c0ad3f1109',
    'lab': 'tm_e854a94641613372a4170daba28407ae',
    'bacteria': 'tm_68c008bfb37f663c81d581287b267a20',
    'univ': 'tm_7641e5f4e7e8517bd0477fd81e3de1b8'
}

rf = open(infile, 'r')
for i, line in enumerate(rf):
    # コメント行は無視する
    if line.startswith('#'):
        continue

    # 空行は無視する
    if len(line.strip()) == 0:
        continue

    # 入力ファイルはTSVファイルであること
    array = line.split('\t')

    query = array[0]
    dict  = array[1]
    match = array[2]
    count = int(array[3])

    idx = idxmap[dict]

    # query文字列中でエラー原因となる文字を置換する
    query = query.replace('\\', '\\\\')

    print("query      = " + query)
    print("dictionary = " + dict)
    print("  index    = " + idx)
    print("match      = " + match)
    print("count      = " + str(count))

    # 出力ディレクトリは連番で管理
    outdir = "input/" + str(i)
    if os.path.isdir(outdir) == False:
        os.makedirs(outdir, exist_ok=True)

    #
    # output docs.ndjson
    #
    wf = open(outdir + '/docs.ndjson', 'w')

    # 繰り返し数に基づいて正解データを組み立てる
    for i in range(0, count):
        offset = i * 3 + 4
        doc_st = array[offset]
        if doc_st == '':
            continue

        doc_id = array[offset + 1].strip()
        doc_rk = ''
        if len(array) > (offset + 2):
            doc_rk = array[offset + 2]

        if doc_rk == '':
            doc_rk = str(count - i)

        doc_rk = doc_rk.strip()

        print(f'[{i}] = "{doc_st}"({doc_id}), rate={doc_rk}')
        print('{"_index": "%s", "_id": "%s", "rating": %s}' % (idx, doc_id, doc_rk), file=wf)

    wf.close()

    #
    # output query.json
    #
    ifq = open('query.template', 'r')
    wfq = open(outdir + '/query.json', 'w')
    
    # query.templateファイルにあるキーワード部分を置換して出力する
    for templine in ifq:
        outstr = templine.replace('###KEYWORD###', query).strip('\n')
        print(outstr, file=wfq)

    wfq.close()
    ifq.close()
