#!/usr/bin/env python
import re

common_modifiers = {}

with open("CommonModifiers.txt","r") as file:
    for line in file:
        common_modifiers[line.strip()] = 1

def text_has_space_b4_cm(text):
    space_b4_cm_flag = False
    words = text.strip().split()
    for i in range(1, len(words)):
        space_b4_cm_flag = space_b4_cm_flag or common_modifiers.get(words[i]) == 1
    return space_b4_cm_flag

def text_has_hyphen_b4_cm_or_others(text):
    judge = True
    hyphen_b4_cm_flag = False
    cm_flag = False
    text = text.strip()
    for match in re.finditer(r"\W", text):
        s_pos = match.start()
        target = text[s_pos + 1:]
        ws_pos = target.find(" ")
        if ws_pos > -1:
            target = target[:ws_pos]
        if common_modifiers.get(target) == 1:
            cm_flag = True
        if text[s_pos] == "-":
            hyphen_b4_cm_flag = True
        if cm_flag and not hyphen_b4_cm_flag:
            judge = False 
    return judge

if __name__ == '__main__':
    print(text_has_hyphen_b4_cm_or_others("Carbon")) # True, 1 expect
    print(text_has_hyphen_b4_cm_or_others("ABC-activated protein")) # True, 1 expected
    print(text_has_hyphen_b4_cm_or_others("ABC,activated protein")) # False, 0 expected
    print(text_has_hyphen_b4_cm_or_others("ABC activated protein")) # False, 0 expected
    print(text_has_space_b4_cm("Carbon")) # False
    print(text_has_space_b4_cm("ABC-activated protein")) # False
    print(text_has_space_b4_cm("ABC,activated protein")) # False
    print(text_has_space_b4_cm("ABC activated protein")) # True
    print('モジュール名：{}'.format(__name__))