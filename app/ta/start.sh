#!/bin/bash
#app起動
hypnotoad /opt/togoannotator/ta/WebService/annotation2.pl
#コンテナ継続起動用
tail -f /opt/togoannotator/ta/WebService/log/production.log
