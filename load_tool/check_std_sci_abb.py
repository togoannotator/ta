#!/usr/bin/env python

standard_scientific_abbreviations = {}

with open("StdSciAbb.txt","r") as file:
    for line in file:
        standard_scientific_abbreviations[line.strip()] = 1

def text_contains_std_sci_abb(text):
    words = text.strip().split()
    is_contain = False
    for word in words:
        is_contain = is_contain or standard_scientific_abbreviations.get(word) == 1
    return is_contain

if __name__ == '__main__':
    print(text_contains_std_sci_abb("DNA Protein"))
    print(text_contains_std_sci_abb("Hypothetical microRNA Protein"))
    print('モジュール名：{}'.format(__name__))
