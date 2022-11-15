#!/bin/bash
LC_ALL=en_US.utf8
LANG=en_US.utf8
# chk-compliance 用サーバー起動
cd /opt/togoannotator/load_tool_bin
uvicorn api_server:app --port=8000 --host=0.0.0.0
#app起動
hypnotoad /opt/togoannotator/ta/WebService/annotation2.pl
#コンテナ継続起動用
tail -f /opt/togoannotator/ta/WebService/log/production.log
