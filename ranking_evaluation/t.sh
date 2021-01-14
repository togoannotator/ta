#!/bin/bash
DATA=`cat ../ranking_evaluation/CP000776.1.txt`
while read line
do
  echo $line
/Users/tf/.anyenv/envs/pyenv/shims/python make_correct_data_tmplate.py -q "$line" -d "univ"
done << FILE
$DATA
FILE
