#!/usr/bin/env python

freqword = {}

with open("FREQ.txt", "r") as file:
    file.readline()
    file.readline()
    for line in file:
        freqword[line.strip()] = 1

def check_word_is_freq(word):
    return freqword.get(word) == 1

def freqword_is_in(text):
    judge = False
    for w in text.strip().split():
        judge = judge or check_word_is_freq(w)
    return judge

if __name__ == '__main__':
    if check_word_is_freq("hello"):
        print("Freq!")
    else:
        print('"hello" is not freq.')
    if check_word_is_freq("season"):
        print("Freq!")
    if freqword_is_in("this is a test"):
        print("Freq word is in.")
    print('モジュール名：{}'.format(__name__))