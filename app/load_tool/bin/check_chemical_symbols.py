#!/usr/bin/env python

chemical_symbols = {}

with open("ChemicalSymbols.txt","r",encoding="utf-8") as file:
    for line in file:
        chemical_symbols[line.strip()] = 1

def text_contains_symbols(text):
    words = text.strip().split()
    is_contain = False
    for word in words:
        is_contain = is_contain or chemical_symbols.get(word) == 1
    return is_contain

if __name__ == '__main__':
    print(text_contains_symbols("Carbon"))
    print(text_contains_symbols("Protein Carbon"))
    print(text_contains_symbols("Carbon Protein"))
    print(text_contains_symbols("Similar Carbon Protein"))
    print(text_contains_symbols("Ce"))
    print('モジュール名：{}'.format(__name__))
