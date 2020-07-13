FROM centos:7

#媒体配置用ディレクトリ作成
RUN mkdir /opt/togoannotator && \
    mkdir /opt/togoannotator/perl_modules

#Perl環境構築
RUN yum install -y gcc gcc-c++ curl-devel perl perl-App-cpanminus zlib-devel
ADD ./modules.txt /opt/togoannotator/perl_modules/modules.txt
RUN cpanm < /opt/togoannotator/perl_modules/modules.txt

#アプリ媒体を取得する
ADD ./ta_files /opt/togoannotator/ta
ADD ./start.sh /opt/togoannotator/start.sh

##シンボリックリンクの作成
#RUN cd /opt/togoannotator/ta/WebService/ && \
#    ln -s -f ../conf/dictionary.json ./annotation.json && \
#    ln -s -f ./annotation.json ./annotation2.json

#アプリ起動準備
RUN mkdir /opt/togoannotator/ta/WebService/log && \
    chmod 755 /opt/togoannotator/start.sh

#取得したアプリを起動する
CMD ["/opt/togoannotator/start.sh"]
