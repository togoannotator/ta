#!/usr/bin/env python3
# coding=utf-8

import gspread
from oauth2client.service_account import ServiceAccountCredentials

#scope = ['https://spreadsheets.google.com/feeds']
#creds = ServiceAccountCredentials.from_json_keyfile_name('projectpubcasefinder-0de72011938f.json', scope)
#creds = ServiceAccountCredentials.from_json_keyfile_name('creds.json', scope)
#client = gspread.authorize(creds)

gc = gspread.service_account()
sh = gc.open("CurationDictionary")

def getDictionary(dictionaryType):
  sheet = sh.worksheet(dictionaryType)
  all = sheet.get_all_values()
  firstrow = True
  for row in all:
      if firstrow:
          firstrow = False
          continue
      print('\t'.join(map(str, row)))

#getDictionary("ValidationWhiteDictionary")
#getDictionary("ValidationBlackDictionary")
getDictionary("ConvtableDictionary")
#getDictionary("product_checklist")
