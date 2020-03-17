#!/bin/bash
set -e
set -u
set -o pipefail

if [ ${1+hoge} ]; then ARG=$1; else ARG=""; fi
BINDIR=/usr/local/bin
ROOTDIR=/opt/services/ta
/bin/cpanm --local-lib=${HOME}/perl5 local::lib && eval $(perl -I ${HOME}/perl5/lib/perl5/ -Mlocal::lib)

cd ${ROOTDIR}

start() {
    ${BINDIR}/hypnotoad WebService/annotation2.pl
    return 0
}
stop() {
    ${BINDIR}/hypnotoad -s WebService/annotation2.pl
    return 0
}
restart() {
    ${BINDIR}/hypnotoad WebService/annotation2.pl
    return 0
}

case "$ARG" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  *)
    echo $"Usage: $0 {start|stop|restart}"
    exit 1
esac
