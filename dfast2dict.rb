#!/usr/bin/env ruby

require 'roo'

# https://drive.google.com/drive/u/0/folders/0BzSRwHTQsTZ0b2JIc29RTk53ZHM
# からdfast_curationを取得する

File.open("dict_dfast_lab.txt", "w") do |fw| 
file = 'dfast_curation/ReferenceDB_clusterMembers.xlsx'
xlsx = Roo::Excelx.new(file)
keys = xlsx.row(xlsx.first_row)
(xlsx.first_row + 1 .. xlsx.last_row).each do |idx|
#(xlsx.first_row + 1 .. xlsx.last_row).first(10).each do |idx|
  vals = xlsx.row(idx)
  next if vals[0] == nil
  hash =  Hash[*keys.zip(vals).flatten]
  #puts vals
  #puts hash
  #null No. OK  change  protein name  old
  #
  if hash['product'].match(" / ")
      hash['product'].split(" / ").each do |p|
          fw.puts [ "", hash['clusterID'], "", "", p, p].join("\t")
      end
  else
    fw.puts [ "", hash['clusterID'], "", "", hash['product'], hash['H1']].join("\t")
    fw.puts [ "", hash['clusterID'], "", "", hash['product'], hash['H2']].join("\t") unless hash['H2'].nil?
    fw.puts [ "", hash['clusterID'], "", "", hash['product'], hash['H3']].join("\t") unless hash['H3'].nil?
  end

  #warn hash['product'] if hash['product'].match("/")
end

end

File.open("dict_dfast_eco.txt", "w") do |fw| 

  file_eco = 'dfast_curation/ecoli_annotation_curated_YT20170707.xlsx'
  xlsx = Roo::Excelx.new(file_eco)
  keys = xlsx.row(xlsx.first_row)
  (xlsx.first_row + 1 .. xlsx.last_row).each do |idx|
  #(xlsx.first_row + 1 .. xlsx.last_row).first(10).each do |idx|
  vals = xlsx.row(idx)
  next if vals[0] == nil
  hash =  Hash[*keys.zip(vals).flatten]
  #null No. OK  change  protein name  old
  if hash['product (curated)'].match(" / ")
      hash['product (curated)'].split(" / ").each do |p|
          fw.puts [ "", hash['cluster'], "", "", p, p].join("\t")
      end
  else
    fw.puts [ "", hash['cluster'], "", "", hash['product (curated)'], hash['common_product']].join("\t")
    fw.puts [ "", hash['cluster'], "", "", hash['product (curated)'], hash['ecogene']].join("\t") unless hash['ecogene'].nil?
  end

  #puts hash['product (curated)'] if hash['product (curated)'].match("/")
end


end


