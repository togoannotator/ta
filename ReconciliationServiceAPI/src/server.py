import argparse
import asyncio
import json
import time

import uvicorn.config
from fastapi import FastAPI, Form, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from starlette.middleware.cors import CORSMiddleware
from starlette.requests import Request

from es.esaccessor import EsAccessor
from models.reconciliation import ReconciliationResponse
from utils.logging import ServerLogger

LOG_LEVEL = 'INFO'
API_TIMEOUT = 60  # 秒

app = FastAPI()
logger = ServerLogger(LOG_LEVEL).logger

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)


class DBError(Exception):
    status_code: int = 503
    detail: str = 'DBとの接続に失敗しました。'


@app.middleware("http")
async def timeout_middleware(request: Request, call_next):
    """
    タイムアウトエラー時にエラーを返すミドルウェア
    :param request:
    :param call_next:
    :return:
    """
    try:
        start_time = time.time()
        return await asyncio.wait_for(call_next(request), timeout=API_TIMEOUT)
    except asyncio.TimeoutError:
        process_time = time.time() - start_time
        return JSONResponse(
            {"detail": "APIタイムアウトが発生しました。", "processing_time": process_time},
            status_code=status.HTTP_504_GATEWAY_TIMEOUT)


@app.exception_handler(RequestValidationError)
async def request_validation_exception_handler(request: Request,
                                               exc: RequestValidationError):
    """
    リクエストのバリデーションエラー
    :param request:
    :param exc:
    :return:
    """
    logger.warning("Request Validation Error")
    logger.warning(
        jsonable_encoder({"detail": exc.errors()}))
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=jsonable_encoder({"detail": exc.errors(), "body": exc.body}),
    )


@app.exception_handler(ValidationError)
async def response_validation_exception_handler(request: Request,
                                                exc: ValidationError):
    """
    レスポンスのバリデーションエラー
    :param request:
    :param exc:
    :return:
    """

    logger.warning("Response Validation Error")
    logger.warning(
        jsonable_encoder({"detail": exc.errors()}))

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=jsonable_encoder({"detail": exc.errors()}),
    )


@app.exception_handler(DBError)
async def db_error_handler(_: Request, exc: DBError):
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content=jsonable_encoder({"detail": exc.detail}),
    )


@app.get("/")
@app.post("/", response_model=ReconciliationResponse)
async def reconcile(queries=Form(None), query=Form(None)):
    """
    Reconciliatin API のエンドポイント。
    クエリがURLエンコードされた文字列の場合と、JSONの場合があるため、
    リクエストバリデーションは型判定後にかける
    :param query:
    :param queries:
    :return:
    """

    if queries is None and query is None:
        response_body = make_manifest_response()
        return response_body

    query_body = json.loads(queries)
    response_body = make_reconciliation_response(query_body)
    return response_body


def make_reconciliation_response(query_body: dict):
    try:
        es = EsAccessor(hosts=args.host, port=args.port,
                        index_pattern=args.index_pattern)
    except Exception as e:
        raise DBError from e

    # Elasticsearchへの検索クエリを生成する
    query = EsAccessor.gen_reconcile_query(query_body)

    # Elasticsearchに検索する
    res = es.msearch(query)

    # 検索結果を加工してレスポンスを生成する
    res = EsAccessor.convert_es_response(res, query_body)
    return res


def make_manifest_response():
    # マニフェスト情報を返す
    searvice_manifest = {
        "name": "TogoAnnotator",
        "identifierSpace": "",
        "schemaSpace": "",
        "view": {
            "url": ""
        }
    }
    return searvice_manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('host')
    parser.add_argument('port')
    parser.add_argument('index_pattern')
    args = parser.parse_args()
    log_config = uvicorn.config.LOGGING_CONFIG
    log_config["formatters"]["default"]["use_colors"] = False
    log_config["formatters"]["access"]["use_colors"] = False
    uvicorn.run(app, log_config=log_config, host="0.0.0.0", port=8000,
                reload=False)
