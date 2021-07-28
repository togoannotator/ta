FROM centos:7

ENV LANG=ja_JP.UTF-8

# python 3.9.2をインストールする
RUN yum -y install \
  wget \
  make \
  gcc \
  zlib-devel \
  openssl-devel \
  libffi-devel
RUN wget https://www.python.org/ftp/python/3.9.2/Python-3.9.2.tgz && tar xzf Python-3.9.2.tgz
WORKDIR /Python-3.9.2/
RUN ./configure && make && make install


# 必要なライブラリを書いたrequirements.txtを用意する
COPY src/requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

# ソースコードをコンテナ内にコピーする
WORKDIR /
COPY src src
ARG host
ARG port
ARG index_pattern

ENV host $host
ENV port $port
ENV index_pattern $index_pattern

CMD python3 ./src/server.py $host $port $index_pattern
