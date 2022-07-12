FROM centos:7

ENV LANG=ja_JP.UTF-8
RUN localedef -v -c -i ja_JP -f UTF-8 ja_JP.UTF-8; echo"";

RUN yum install -y epel-release
RUN yum install -y \
  gcc \
  jq \
  python36 \
  python36-devel

RUN pip3 install \
  elasticsearch==7.7.1 \
  pyahocorasick \
  regex

RUN mkdir -p /opt/load_tool
COPY bin /opt/load_tool/bin
COPY pipeline /opt/load_tool/pipeline
RUN chmod a+x /opt/load_tool/bin/data_load.sh

CMD ["/opt/load_tool/bin/data_load.sh"]
