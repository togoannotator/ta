from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
import used_by_perl

app = FastAPI()

chk = used_by_perl.TsvElasticsearchConnector()

@app.get("/")
def root():
   return {"Hello":"こんにちは"}

@app.get("/text/{name}")
def create_user(name: str):
   result = jsonable_encoder(chk.eval_guidelines(name))
   return JSONResponse(content=result)
