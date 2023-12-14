from elasticsearch import Elasticsearch, RequestsHttpConnection


class MyConnection(RequestsHttpConnection):
    """ Proxy設定のためのConnectionクラス
    """

    def __init__(self, *args, **kwargs):
        proxies = kwargs.pop('proxies', {})
        super(MyConnection, self).__init__(*args, **kwargs)
        self.session.proxies = proxies


class ESAccessor:
    """ Elasticsearchクライアントを扱う
    """

    def __init__(self, host='127.0.0.1', port='9200', user='elastic', password='changeme', proxies={}):
        self.es = Elasticsearch(hosts=[f'{host}:{port}'], http_auth=(user, password), connection_class=MyConnection,
                                proxies=proxies, timeout=300)

    def call_rank_eval(self, body={}, index=None):
        res = self.es.rank_eval(body, index=index)
        return res

    def put_index_template(self, name='my_template', body={}):
        self.es.indices.put_template(name, body)

    def index(self, index='my_index', body={}, id=None):
        self.es.index(index=index, body=body, id=id)

    def index_exists(self, index_name):
        return self.es.indices.exists(index_name)
