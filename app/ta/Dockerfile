FROM centos:7

#プロキシ環境下では4,5行目のコメントアウトを外す
#ARG http_proxy
#ARG https_proxy

#媒体配置用ディレクトリ作成
RUN mkdir -p  /opt/togoannotator/perl_modules

#Perl環境構築
RUN yum install -y \
  curl-devel \
  gcc \
  gcc-c++ \
  perl \
  perl-App-cpanminus \
  zlib-devel
COPY ./ta/modules.txt /opt/togoannotator/perl_modules/modules.txt
RUN cpanm < /opt/togoannotator/perl_modules/modules.txt

#アプリ媒体を取得する
COPY ./ta/ta_files /opt/togoannotator/ta
COPY ./ta/start.sh /opt/togoannotator/start.sh

#アプリ起動準備
RUN mkdir /opt/togoannotator/ta/WebService/log && \
    chmod 755 /opt/togoannotator/start.sh

#取得したアプリを起動する
ENTRYPOINT ["/opt/togoannotator/start.sh"]
