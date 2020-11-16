#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0`; pwd)

EXEC_NAME=$(basename $0 .sh)
EXEC_DATE=$(date "+%Y%m%d_%H%M%S")

ELASTICSEARCH_HOST=elasticsearch
ELASTICSEARCH_IP=9200

TOOL_DIR=/opt/load_tool
BIN_DIR=${TOOL_DIR}/bin
LOG_DIR=${TOOL_DIR}/logs
LOG_FILE=${LOG_DIR}/${EXEC_DATE}_${EXEC_NAME}.log
PIPELINE_DIR=${TOOL_DIR}/pipeline
DEFS_DIR=${TOOL_DIR}/defs
ES_DATA=${TOOL_DIR}/es_data

logger () {
    message=$1
    log_file=$2
    echo "[$(date +'%F %T')] ${message}" 2>&1 | tee -a ${log_file}
}

mkdir -p ${LOG_DIR}

logger "Elasticsearch起動状態チェック開始" ${LOG_FILE}
while true; do
    elastic_status=$(curl --noproxy elasticsearch -s -X GET http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_IP}/_cluster/health?pretty=true | grep '"status" : "green"' | wc -l )
    # 正常に起動した場合にチェック処理を終了
    if [ ${elastic_status} -eq 1 ]; then
        break
    fi
    logger "Waiting for elasticsearch..." ${LOG_FILE}
    sleep 10s
done
logger "Elasticsearch起動状態チェック終了" ${LOG_FILE}

logger "データロード処理を開始します。" ${LOG_FILE}
START_TIME=`date '+%s'`

logger "templateの登録開始" ${LOG_FILE}
curl --noproxy elasticsearch -s -H "Content-Type: application/json" -XPOST http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_IP}/_template/tm_dict -d @${DEFS_DIR}/template_tm_dict.json | jq | tee -a ${LOG_FILE}
logger "templateの登録終了" ${LOG_FILE}

logger "pipelineの登録開始" ${LOG_FILE}
# pipeline_list.txtに書かれている内容を繰り返し処理
while read line ; do
    # リストからURL名、jsonファイル名を取得
    url_pipeline_name=$(echo ${line} | awk -F ',' '{print $1}')
    pipeline_json=$(echo ${line} | awk -F ',' '{print $2}')

    # pipeline登録
    logger "${url_pipeline_name}" ${LOG_FILE}
    curl --noproxy elasticsearch -s -H "Content-Type: application/json" \
      -XPUT http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_IP}/_ingest/pipeline/${url_pipeline_name} \
      -d @${PIPELINE_DIR}/${pipeline_json} | tee -a ${LOG_FILE}

    # ログ表示を見やすいように改行
    echo -n -e "\n" | tee -a ${LOG_FILE}
done < ${BIN_DIR}/pipeline_list.txt
logger "pipelineの登録終了" ${LOG_FILE}

logger "データロード事前準備開始" ${LOG_FILE}
touch ${BIN_DIR}/FREQ.txt | tee -a ${LOG_FILE}
sed -i -e "s/TsvElasticsearchConnector(\".*:.*\"/TsvElasticsearchConnector(\"${ELASTICSEARCH_HOST}:${ELASTICSEARCH_IP}\"/g" ${BIN_DIR}/pipeline_available_load_dict4es_ta.py | tee -a ${LOG_FILE}
logger "データロード事前準備終了" ${LOG_FILE}

logger "既存データ削除開始" ${LOG_FILE}
curl --noproxy elasticsearch -s -XDELETE http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_IP}/tm_* | tee -a ${LOG_FILE}
echo -n -e "\n" | tee -a ${LOG_FILE}
logger "既存データ削除終了" ${LOG_FILE}


logger "データロード処理開始" ${LOG_FILE}

cd ${BIN_DIR}

logger "--- cyanobacteria ---" ${LOG_FILE}
python3.6 -u pipeline_available_load_dict4es_ta.py --file ${ES_DATA}/dict_cyanobacteria_20151120_with_cyanobase.txt --index tm_53a186f8c95c329d6bddd8bc3d3b4189 | tee -a ${LOG_FILE}

logger "--- ecoli ---" ${LOG_FILE}
python3.6 -u pipeline_available_load_dict4es_ta.py --file ${ES_DATA}/dict_dfast_eco.txt --index tm_f0a37107d9735025c81673c0ad3f1109 | tee -a ${LOG_FILE}

logger "--- lab ---" ${LOG_FILE}
python3.6 -u pipeline_available_load_dict4es_ta.py --file ${ES_DATA}/dict_dfast_lab.txt --index tm_e854a94641613372a4170daba28407ae | tee -a ${LOG_FILE}

logger "--- bacteria ---" ${LOG_FILE}
python3.6 -u pipeline_available_load_dict4es_ta.py --file ${ES_DATA}/UniProtLeeCurated.txt --index tm_68c008bfb37f663c81d581287b267a20 | tee -a ${LOG_FILE}

logger "--- universal ---" ${LOG_FILE}
python3.6 -u pipeline_available_load_dict4es_ta.py --file ${ES_DATA}/dict_universal_20201006.txt --index tm_7641e5f4e7e8517bd0477fd81e3de1b8 | tee -a ${LOG_FILE}

logger "データロード処理終了" ${LOG_FILE}

logger "Elasticsearch index確認開始" ${LOG_FILE}
curl --noproxy elasticsearch -s -X GET "http://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_IP}/_cat/indices/tm_*?v&s=i" | tee -a ${LOG_FILE}
logger "Elasticsearch index確認終了" ${LOG_FILE}


END_TIME=`date '+%s'`
PROCESSING_TIME=$((END_TIME - START_TIME))
logger "データロード処理を終了します。(${PROCESSING_TIME}秒)" ${LOG_FILE}
