# KeyWordsByUniprotBeforeWithOrWithoutNITEBefore.txt から次のファイルを生成するコマンド。
#
# 1. KeyWordsByUniprotBeforeWithOrWithoutNITEBefore4Xsquare.txt
# 2. KeyWordsByUniprotBeforeWithOrWithoutNITEBefore4Xsquare2nd.txt
# 3. KeyWordsByUniprotBeforeWithoutNITEBefore.txt

perl -ne 'chomp;my ($mb, $kws) = split /\t/;my @kws = split / # /, $kws;do{$hash{$mb}{$_}++} for @kws;END{for (sort {$hash{"o"}{$b}<=>$hash{"o"}{$a}} keys %{$hash{"o"}}){print join("\t", ("o", $_, $hash{"o"}{$_})), "\n"}; for (sort {$hash{"x"}{$b}<=>$hash{"x"}{$a}} keys %{$hash{"x"}}){print join("\t", ("x", $_, $hash{"x"}{$_})), "\n"}}' KeyWordsByUniprotBeforeWithOrWithoutNITEBefore.txt  > KeyWordsByUniprotBeforeWithOrWithoutNITEBefore4Xsquare.txt

perl -ne 'chomp;my ($mb, $kws) = split /\t/;my @kws = split / # /, $kws;do{$hash{$mb}{$_}++} for @kws;END{for (keys %{$hash{"o"}}){next unless $hash{"x"}{$_};print join("\t", ($_, $hash{"o"}{$_}, $hash{"x"}{$_},  $hash{"o"}{$_} + $hash{"x"}{$_})), "\n"}}' KeyWordsByUniprotBeforeWithOrWithoutNITEBefore.txt  > KeyWordsByUniprotBeforeWithOrWithoutNITEBefore4Xsquare2nd.txt

perl -ne 'chomp;my ($mb, $kws) = split /\t/;my @kws = split / # /, $kws;do{$hash{$mb}{$_}++} for @kws;END{for (sort {$hash{"x"}{$b} <=> $hash{"x"}{$a}} keys %{$hash{"x"}}){next if $hash{"o"}{$_};print join("\t", ($_, $hash{"x"}{$_})), "\n"}}' KeyWordsByUniprotBeforeWithOrWithoutNITEBefore.txt > KeyWordsByUniprotBeforeWithoutNITEBefore.txt