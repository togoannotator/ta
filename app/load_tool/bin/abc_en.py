#!/usr/bin/env python

# PerlのモジュールLingua::EN::ABCの移植

import json
import re

a = []
b = []
as_ = []
bs_ = []
any2e = {}
abc = open("abc.json", 'r')
for e in json.load(abc):
    any2e[e["a"]] = e
    any2e[e["b"]] = e
    a.append(e["a"])
    b.append(e["b"])
    if e.get("ca") == True:
        e["co"] = e["a"]
    else:
        e["co"] = e["b"]
    if e.get("oxford") == True:
        e["bo"] = e["a"]
    else:
        e["bo"] = e["b"]
    if e.get("aam") == True:
        e["ao"] = e["a"]+"/"+e["b"]
    else:
        e["ao"] = e["a"]

for k in any2e:
    e = any2e[k]
    if e.get("s") == True and not (e.get("bam") == True or e.get("aam") == True):
        as_.append(e["a"])
        bs_.append(e["b"])

a_re = re.compile(r"\b((" + "|".join(a) + r"))(s?)\b")
b_re = re.compile(r"\b((" + "|".join(b) + r"))(s?)\b")
#bo_re = re.compile(r"((" + "|".join(bo) + r"))(s?)\b")
as_re = re.compile(r"\b((" + "|".join(as_) + r"))(s?)\b")
bs_re = re.compile(r"\b((" + "|".join(bs_) + r"))(s?)\b")

def a2b(text, options = {}):
    return text

def b2a(text, options = {}):
    if options.get("s") == True:
        m = bs_re.match(text)
        if m:
            text = bs_re.sub(any2e[m.group(1)]["ao"] + "\\3", text)
    else:
        m = b_re.match(text)
        if m:
            text = b_re.sub(any2e[m.group(1)]["ao"] + "\\3", text)
    return text

def a2c(text, options = {}):
    return text

def c2a(text, options = {}):
    return text

def c2b(text, options = {}):
    return text

def b2c(text, options = {}):
    return text

if __name__ == '__main__':
    print(b2a("civilisation"))
    print('モジュール名：{}'.format(__name__))
