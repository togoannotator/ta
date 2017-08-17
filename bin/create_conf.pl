#!/usr/bin perl

use warnings;
#use strict;
use Data::Dumper;
use utf8;
use Encode qw/encode decode/;
use FindBin qw($Bin);
use lib "$Bin/..";
use Text::TogoAnnotator;
use JSON;
use File::Basename;
use Tie::IxHash;


my $sysroot = "$Bin/..";

my $ports = {
'dict_uniprot_dictionary_20161215' => 5001,
'dict_cyanobacteria_20151120_with_cyanobase' => 5002,
'dict_dfast_eco' => 5003,
'dict_dfast_lab' => 5004,
};

my $conf ={};
opendir(DIR, "$sysroot/data");
foreach my $dict_file (readdir(DIR)){
    next unless $dict_file =~/^dict_/; 
    #next if $dict_file =~/cyanobacteria/;
    #next if $dict_file =~/uniprot/;
    next if $dict_file =~/curated/;
    #print $dict_file,"\n";
    #print "# Generating a dictionary from soruce: \"$sysroot/data/$dict_file\"\n";
    my $regex_suffix = qw(\..+$); #qr/\.[^\.]+$/;
    my ($base, $dir, $suffix) = fileparse( $dict_file, $regex_suffix );
    #print $base,"\n";
    my $o =  {
        "cos_threshold" =>  0.6 ,
        "e_threashold" =>  30,
        "cs_max" => 5,
        "n_gram" => 3,
        #"sysroot"=> $sysroot,
        "niteAll"=> "$sysroot/data/$dict_file",
        "curatedDict"=> ""
        #"useCurrentDict"=> 1
    };
     $o->{'port'} = $ports->{$base}; 
#    $o->{'sysroot'} = $sysroot;
#    $o->{'useCurrentDict'} = 0;
    #print encode_json $o;
    tie %{$conf->{$base}}, 'Tie::IxHash';
    $conf->{$base} = $o;
    #tie %{$conf->{$base}}, 'Tie::IxHash';
    $conf->{'_default'} = $o if $dict_file =~/uniprot/;
    #print Dumper $o;
    #next;
    #Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "dict_cyanobacteria_20151120.txt", "dict_cyanobacteria_curated.txt", 0);
}
closedir(DIR);
print encode_json $conf;

    #$cos_threshold = shift; # cosine距離で類似度を測る際に用いる閾値。この値以上類似している場合は変換対象の候補とする。
    #$e_threashold  = shift; # E列での表現から候補を探す場合、辞書中での最大出現頻度がここで指定する数未満の場合のもののみを対象とする。
    #$cs_max        = shift; # 複数表示する候補が在る場合の最大表示数
    #$n_gram        = shift; # N-gram
    #$sysroot       = shift; # 辞書や作業用ファイルを生成するディレクトリ
    #$niteAll       = shift; # 辞書名
    #$curatedDict   = shift; # curated辞書名（形式は同一）
    #$useCurrentDict= shift; # 既に内部利用辞書ファイルがある場合には、それを削除して改めて構築するか否か

