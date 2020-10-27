#!/usr/bin/env python

abbreviations = {}

with open("Allie_Short_Form_mt_99.txt", "r") as file:
    for line in file:
        abbreviations[line.strip()] = 1

def check_word_is_abbreviation(word):
    return abbreviations.get(word) == 1

if __name__ == '__main__':
    print("SPF:", end="")
    print(check_word_is_abbreviation("SPF"))
    print("spf:", end="")
    print(check_word_is_abbreviation("spf"))
    print('モジュール名：{}'.format(__name__))