#!/usr/bin/env python
import re
import ahocorasick

enzymes = {}
pattern = re.compile(r"[:;]")
A = ahocorasick.Automaton()

with open("enzyme_accepted_names.txt","r") as file:
    for line in file:
        lhw = ' '.join([w[0].lower() + w[1:] for w in line.strip().split()])
        A.add_word(' ' + lhw + ' ', lhw)
        enzymes[lhw] = 1
    A.make_automaton()

def text_contains_col_semi(text):
    words = text.strip().split()
    lhw = ' '.join([w[0].lower() + w[1:] for w in words])
    target = ' ' + lhw + ' '
    is_contain = False
    for end_index, original_value in A.iter(target):
        start_index = end_index - len(original_value)
        target = target[:start_index] + '_'*len(original_value) + target[end_index:]
    return pattern.search(target) != None 

if __name__ == '__main__':
    print(text_contains_col_semi("Carbon"))
    print(text_contains_col_semi("phycocyanobilin:ferredoxin oxidoreductase"))
    print(text_contains_col_semi("Nucleosome assembly protein 1;1"))
    print(text_contains_col_semi("Ce"))
    print('モジュール名：{}'.format(__name__))