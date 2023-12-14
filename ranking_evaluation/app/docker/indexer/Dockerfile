FROM python:3.7-alpine
WORKDIR /work
COPY requirements.txt requirements.txt
COPY src src
RUN pip install -r requirements.txt
ENV PYTHONPATH "/work"
WORKDIR /work/src/indexer
ENTRYPOINT ["python", "indexer.py"]
