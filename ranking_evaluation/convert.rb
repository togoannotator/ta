#!/usr/bin/env ruby
require 'pp'

a = %w(#検索キーワード 辞書 match count 結果1 結果1_ID 結果1_検索順位 結果2 結果2_ID 結果2_検索順位 結果3 結果3_ID 結果3_検索順位 結果4 結果4_ID 結果4_検索順位 結果5 結果5_ID 結果5_検索順位 結果6 結果6_ID 結果6_検索順位 結果7 結果7_ID 結果7_検索順位 結果8 結果8_ID 結果8_検索順位 結果9 結果9_ID 結果9_検索順位 結果10 結果10_ID 結果10_検索順位)
puts a.join("\t")

  File.open('./x') do |file|
    hash ={}

    file.each_line do |line|
      next if line.match(/^#/)
      a = line.chomp.split("\t")
      query = a.shift(4)
      q = query[0]
      hash[q] = query unless hash[q]
      hash[q].push(a)
      #hash[query].push(a)
    end

    hash.each do |k,v|
        puts v.flatten.join("\t")
    end
  end

  #hash.each do |k,v|
  #   #puts k 
  #end

