#!/usr/bin/env python
# coding=utf-8

import gspread
from oauth2client.service_account import ServiceAccountCredentials

scope = ['https://spreadsheets.google.com/feeds']
creds = ServiceAccountCredentials.from_json_keyfile_name('creds.json', scope)
client = gspread.authorize(creds)
# ValidationBlackDictionary

def getDictionary(dictionaryType):
  f = open(dictionaryType+".txt", 'w')
  sheet = client.open("CurationDictionary").worksheet(dictionaryType)
  all = sheet.get_all_values()
  firstrow = True
  for row in all:
      if firstrow:
          firstrow = False
          continue
      if len(row[0]) == 0:
          continue
      print('\t'.join(map(str, row)))
      f.write(row[0]+"\n")
  f.close()

getDictionary("ValidationWhiteDictionary")
getDictionary("ValidationBlackDictionary")

