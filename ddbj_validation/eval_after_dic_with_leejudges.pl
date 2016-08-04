#!/usr/bin/env perl

=head
バクテリアを対象としたENA→UniProt(Reviewed)辞書について李さんの評価を加えるスクリプト

ENAをBefore、対応するUniProt ReviewedをAfterとする書換辞書（バクテリア）について、
李さんの辞書に含まれないものを李さんにチェックして頂いた結果を $leejudge でオープン。
EMBLデータに含まれているローカスタグを抽出したものを $locustag でオープン。
上記のUniProt ReviewedとENAの対応を取得した結果を $tgd でオープン。
=cut

use warnings;
use strict;
use Fatal qw/open/;
use PerlIO::gzip;
use Text::Trim;
use Text::Match::FastAlternatives;

my @dictionary;
open(my $dic, "20151118_words.txt");
while(<$dic>){
    chomp;
    trim;
    push @dictionary, $_;
}
close $dic;

my $matcher = Text::Match::FastAlternatives->new( @dictionary );

my %levels;

open(my $leejudge, "check_wordsNotInDictionary_ENA_2_ReviewedUniProt.txt");
while(<$leejudge>){
    chomp;
    trim($_);
    my ($w, $s, $j) = split /\t/;
    next if $j eq "level";
    $levels{$w} = $j;
}
close($leejudge);

my (%afters, %eid2lct);

open(my $locustag, "../uniprot_evaluation/Embl2LocusTag.txt");
while(<$locustag>){
    chomp;
    my ($eid, $lct) = split /\t/;
    next if $eid eq '"emblid"';
    $lct =~ s/^"//;
    $lct =~ s/"$//;
    push @{ $eid2lct{$eid} }, $lct;
    if(index($lct, "_") > -1){
	$lct =~ s/_//g;
	push @{ $eid2lct{$eid} }, $lct;
    }
}
close($locustag);

open(my $tgd, "<:gzip", "../uniprot_evaluation/matched.txt.gz");
while(<$tgd>){
    chomp;
    my ($id, $af, $bf) = split /\t/;
    $af =~ s/^"//;
    $af =~ s/"$//;
    $bf =~ s/^"//;
    $bf =~ s/"$//;
    trim( $af );
    my $origin = $af;
    $af =~ y|-()[]/,| |;
    $af =~ s/\'/ /g;
    $af =~ s/  +/ /g;
    trim( $af );
    my @lct;
    next if $afters{$af};
    # ENAのIDをキーにして対象DBエントリにLocus Tagが含まれているか確認し、
    # 含まれている場合は、それがUniProt Reviewedのデフィニションに含まれるかを確認し、
    # 含まれていたらそれを除去する。
    if( $eid2lct{$id} ){
	for ( @{ $eid2lct{$id} } ){
	    if(index($af, $_) > -1){
		$af =~ s/\b$_\b//;
		$af =~ s/  +/ /g;
		trim( $af );
		push @lct, $_;
	    }
	}
    }
    next if $afters{$af};
    $afters{$af}++;
    # 書換後のデフィニションについてワード単位で李さん辞書に基くレベルを付与
    # 0: 辞書から除外(locus_tag 類の混入)
    # 1: gene 名などの略語類(辞書に追加)
    # 2: 辞書に追加
    my %hash;
    my @levelseq;
    for (split / /, $af) {
	if($matcher->exact_match($_)){
	    $hash{2}++;
	    push @levelseq, 2;
	}elsif(defined($levels{$_})){
	    $hash{$levels{$_}}++;
	    push @levelseq, $levels{$_};
	}else{
	    push @levelseq, '-';
	}
    }
    my $result = join("", (sort {$a <=> $b} keys %hash));
    print join("\t", ($af, $result, "[". join(":", @lct). "]", $origin, $bf, join("", @levelseq))), "\n";
}
close($tgd);

__END__
