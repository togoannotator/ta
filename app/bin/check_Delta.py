#!/usr/bin/env python
import re

delta_word = {}

with open("BeginWithDelta.txt", "r") as file:
    for line in file:
        delta_word[line.strip()] = 1

def text_contains_Delta_steroid_fatty_acid(word):
    word = word.strip()
    if re.search("delta", word, re.IGNORECASE):
        print(word)
        return delta_word.get(word) == 1
    else:
        return True

if __name__ == '__main__':
    print(text_contains_Delta_steroid_fatty_acid("Delta(1)-pyrroline-2-carboxylate reductase 1"))
    print(text_contains_Delta_steroid_fatty_acid("3beta-hydroxy-Delta5-steroid"))
    print(text_contains_Delta_steroid_fatty_acid("3beta hydroxy steroid"))
    print('モジュール名：{}'.format(__name__))