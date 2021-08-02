from es.esaccessor import EsAccessor


def test_gen_reconcile_query():
    """
    照合対象1つ、limit指定なし
    normalized_nameに照合対象名がセットされたクエリが返却されること
    """
    query_body = {"q0": {"query": "hypotheticalprotein"}}
    result = EsAccessor.gen_reconcile_query(query_body)
    expected = [
        {
            'query': {
                'bool': {
                    'must': [
                        {
                            'bool': {
                                'should': [
                                    {
                                        'bool': {
                                            'must': [
                                                {
                                                    'term': {
                                                        'query_type': 'term_before'
                                                    }
                                                },
                                                {
                                                    'match': {
                                                        'normalized_name.term': {
                                                            'query': 'hypotheticalprotein'
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        'bool': {
                                            'must': [
                                                {
                                                    'term': {
                                                        'query_type': 'term_after'
                                                    }
                                                },
                                                {
                                                    'match': {
                                                        'normalized_name.term': {
                                                            'query': 'hypotheticalprotein'
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        'bool': {
                                            'must': [
                                                {
                                                    'term': {
                                                        'query_type': 'mlt_before'
                                                    }
                                                },
                                                {
                                                    'more_like_this': {
                                                        'fields': [
                                                            'normalized_name.mlt'
                                                        ],
                                                        'like': 'hypotheticalprotein',
                                                        'max_query_terms': 100,
                                                        'minimum_should_match': '30%',
                                                        'min_term_freq': 0,
                                                        'min_word_length': 0,
                                                        'max_word_length': 0
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        'bool': {
                                            'must': [
                                                {
                                                    'term': {
                                                        'query_type': 'mlt_after'
                                                    }
                                                },
                                                {
                                                    'more_like_this': {
                                                        'fields': [
                                                            'normalized_name.mlt'
                                                        ],
                                                        'like': 'hypotheticalprotein',
                                                        'max_query_terms': 100,
                                                        'minimum_should_match': '30%',
                                                        'min_term_freq': 0,
                                                        'min_word_length': 0,
                                                        'max_word_length': 0
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                ]
                            }
                        }
                    ],
                    'should': [
                        {
                            'multi_match': {
                                'query': '1',
                                'type': 'most_fields',
                                'fields': [
                                    'guideline_PN001',
                                    'guideline_PN002',
                                    'guideline_PN003',
                                    'guideline_PN004',
                                    'guideline_PN005',
                                    'guideline_PN006',
                                    'guideline_PN007',
                                    'guideline_PN011',
                                    'guideline_PN012',
                                    'guideline_PN013',
                                    'guideline_PN014',
                                    'guideline_PN015',
                                    'guideline_PN016',
                                    'guideline_PN017',
                                    'guideline_PN018',
                                    'guideline_PN019',
                                    'guideline_PN020',
                                    'guideline_PN021',
                                    'guideline_PN022',
                                    'guideline_PN024',
                                    'guideline_PN026',
                                    'guideline_PN027',
                                    'guideline_PN028',
                                    'guideline_PN029',
                                    'guideline_PN030',
                                    'guideline_PN034',
                                    'guideline_PN036',
                                    'guideline_PN037',
                                    'guideline_PN038',
                                    'guideline_PN039',
                                    'guideline_PN041',
                                    'guideline_PN042',
                                    'guideline_PN043',
                                    'guideline_PN047',
                                    'guideline_PN048',
                                    'guideline_PN049',
                                    'guideline_PN050',
                                    'guideline_PN051'
                                ]
                            }
                        }
                    ]
                }
            },
            'profile': 'false',
            'size': 0,
            'aggs': {
                'tags': {
                    'terms': {
                        'field': 'query_type',
                        'size': 4
                    },
                    'aggs': {
                        'top_tag_hits': {
                            'top_hits': {
                                'size': 15,
                                'sort': [
                                    {
                                        '_score': {
                                            'order': 'desc'
                                        }
                                    },
                                    {
                                        'normalized_name': {
                                            'order': 'asc'
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    ]
    assert result == expected


def test_gen_reconcile_query_limit3():
    """
    照合対象1つ、limit指定3
    sizeが3にセットされたクエリが返却されること
    """
    query_body = {"q0": {"query": "hypotheticalprotein", "limit": 3}}
    result = EsAccessor.gen_reconcile_query(query_body)
    expected = [
        {
            'query': {
                'bool': {
                    'must': [
                        {
                            'bool': {
                                'should': [
                                    {
                                        'bool': {
                                            'must': [
                                                {
                                                    'term': {
                                                        'query_type': 'term_before'
                                                    }
                                                },
                                                {
                                                    'match': {
                                                        'normalized_name.term': {
                                                            'query': 'hypotheticalprotein'
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        'bool': {
                                            'must': [
                                                {
                                                    'term': {
                                                        'query_type': 'term_after'
                                                    }
                                                },
                                                {
                                                    'match': {
                                                        'normalized_name.term': {
                                                            'query': 'hypotheticalprotein'
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        'bool': {
                                            'must': [
                                                {
                                                    'term': {
                                                        'query_type': 'mlt_before'
                                                    }
                                                },
                                                {
                                                    'more_like_this': {
                                                        'fields': [
                                                            'normalized_name.mlt'
                                                        ],
                                                        'like': 'hypotheticalprotein',
                                                        'max_query_terms': 100,
                                                        'minimum_should_match': '30%',
                                                        'min_term_freq': 0,
                                                        'min_word_length': 0,
                                                        'max_word_length': 0
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        'bool': {
                                            'must': [
                                                {
                                                    'term': {
                                                        'query_type': 'mlt_after'
                                                    }
                                                },
                                                {
                                                    'more_like_this': {
                                                        'fields': [
                                                            'normalized_name.mlt'
                                                        ],
                                                        'like': 'hypotheticalprotein',
                                                        'max_query_terms': 100,
                                                        'minimum_should_match': '30%',
                                                        'min_term_freq': 0,
                                                        'min_word_length': 0,
                                                        'max_word_length': 0
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                ]
                            }
                        }
                    ],
                    'should': [
                        {
                            'multi_match': {
                                'query': '1',
                                'type': 'most_fields',
                                'fields': [
                                    'guideline_PN001',
                                    'guideline_PN002',
                                    'guideline_PN003',
                                    'guideline_PN004',
                                    'guideline_PN005',
                                    'guideline_PN006',
                                    'guideline_PN007',
                                    'guideline_PN011',
                                    'guideline_PN012',
                                    'guideline_PN013',
                                    'guideline_PN014',
                                    'guideline_PN015',
                                    'guideline_PN016',
                                    'guideline_PN017',
                                    'guideline_PN018',
                                    'guideline_PN019',
                                    'guideline_PN020',
                                    'guideline_PN021',
                                    'guideline_PN022',
                                    'guideline_PN024',
                                    'guideline_PN026',
                                    'guideline_PN027',
                                    'guideline_PN028',
                                    'guideline_PN029',
                                    'guideline_PN030',
                                    'guideline_PN034',
                                    'guideline_PN036',
                                    'guideline_PN037',
                                    'guideline_PN038',
                                    'guideline_PN039',
                                    'guideline_PN041',
                                    'guideline_PN042',
                                    'guideline_PN043',
                                    'guideline_PN047',
                                    'guideline_PN048',
                                    'guideline_PN049',
                                    'guideline_PN050',
                                    'guideline_PN051'
                                ]
                            }
                        }
                    ]
                }
            },
            'profile': 'false',
            'size': 0,
            'aggs': {
                'tags': {
                    'terms': {
                        'field': 'query_type',
                        'size': 4
                    },
                    'aggs': {
                        'top_tag_hits': {
                            'top_hits': {
                                'size': 3,
                                'sort': [
                                    {
                                        '_score': {
                                            'order': 'desc'
                                        }
                                    },
                                    {
                                        'normalized_name': {
                                            'order': 'asc'
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    ]
    assert result == expected


def test_gen_reconcile_multi_query_limit3():
    """
    照合対象2つ、limit指定3
    q0句配下に一つ目、q1句配下に二つ目の照合対象がセットされたクエリが返却されること
    """
    query_body = {"q0": {"query": "hypotheticalprotein", "limit": 3},
                  "q1": {"query": "(2Fe-2S) ferredoxin", "limit": 3}}
    result = EsAccessor.gen_reconcile_query(query_body)
    expected = [
        {
            "query": {
                "bool": {
                    "must": [
                        {
                            "bool": {
                                "should": [
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_before"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "hypotheticalprotein"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_after"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "hypotheticalprotein"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_before"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "hypotheticalprotein",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_after"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "hypotheticalprotein",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                ]
                            }
                        }
                    ],
                    "should": [
                        {
                            "multi_match": {
                                "query": "1",
                                "type": "most_fields",
                                "fields": [
                                    "guideline_PN001",
                                    "guideline_PN002",
                                    "guideline_PN003",
                                    "guideline_PN004",
                                    "guideline_PN005",
                                    "guideline_PN006",
                                    "guideline_PN007",
                                    "guideline_PN011",
                                    "guideline_PN012",
                                    "guideline_PN013",
                                    "guideline_PN014",
                                    "guideline_PN015",
                                    "guideline_PN016",
                                    "guideline_PN017",
                                    "guideline_PN018",
                                    "guideline_PN019",
                                    "guideline_PN020",
                                    "guideline_PN021",
                                    "guideline_PN022",
                                    "guideline_PN024",
                                    "guideline_PN026",
                                    "guideline_PN027",
                                    "guideline_PN028",
                                    "guideline_PN029",
                                    "guideline_PN030",
                                    "guideline_PN034",
                                    "guideline_PN036",
                                    "guideline_PN037",
                                    "guideline_PN038",
                                    "guideline_PN039",
                                    "guideline_PN041",
                                    "guideline_PN042",
                                    "guideline_PN043",
                                    "guideline_PN047",
                                    "guideline_PN048",
                                    "guideline_PN049",
                                    "guideline_PN050",
                                    "guideline_PN051"
                                ]
                            }
                        }
                    ]
                }
            },
            "profile": "false",
            "size": 0,
            "aggs": {
                "tags": {
                    "terms": {
                        "field": "query_type",
                        "size": 4
                    },
                    "aggs": {
                        "top_tag_hits": {
                            "top_hits": {
                                "size": 3,
                                "sort": [
                                    {
                                        "_score": {
                                            "order": "desc"
                                        }
                                    },
                                    {
                                        "normalized_name": {
                                            "order": "asc"
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        },
        {
            "query": {
                "bool": {
                    "must": [
                        {
                            "bool": {
                                "should": [
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_before"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "(2Fe-2S) ferredoxin"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_after"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "(2Fe-2S) ferredoxin"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_before"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "(2Fe-2S) ferredoxin",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_after"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "(2Fe-2S) ferredoxin",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                ]
                            }
                        }
                    ],
                    "should": [
                        {
                            "multi_match": {
                                "query": "1",
                                "type": "most_fields",
                                "fields": [
                                    "guideline_PN001",
                                    "guideline_PN002",
                                    "guideline_PN003",
                                    "guideline_PN004",
                                    "guideline_PN005",
                                    "guideline_PN006",
                                    "guideline_PN007",
                                    "guideline_PN011",
                                    "guideline_PN012",
                                    "guideline_PN013",
                                    "guideline_PN014",
                                    "guideline_PN015",
                                    "guideline_PN016",
                                    "guideline_PN017",
                                    "guideline_PN018",
                                    "guideline_PN019",
                                    "guideline_PN020",
                                    "guideline_PN021",
                                    "guideline_PN022",
                                    "guideline_PN024",
                                    "guideline_PN026",
                                    "guideline_PN027",
                                    "guideline_PN028",
                                    "guideline_PN029",
                                    "guideline_PN030",
                                    "guideline_PN034",
                                    "guideline_PN036",
                                    "guideline_PN037",
                                    "guideline_PN038",
                                    "guideline_PN039",
                                    "guideline_PN041",
                                    "guideline_PN042",
                                    "guideline_PN043",
                                    "guideline_PN047",
                                    "guideline_PN048",
                                    "guideline_PN049",
                                    "guideline_PN050",
                                    "guideline_PN051"
                                ]
                            }
                        }
                    ]
                }
            },
            "profile": "false",
            "size": 0,
            "aggs": {
                "tags": {
                    "terms": {
                        "field": "query_type",
                        "size": 4
                    },
                    "aggs": {
                        "top_tag_hits": {
                            "top_hits": {
                                "size": 3,
                                "sort": [
                                    {
                                        "_score": {
                                            "order": "desc"
                                        }
                                    },
                                    {
                                        "normalized_name": {
                                            "order": "asc"
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    ]
    assert result == expected


def test_gen_reconcile_multi_query_limit0():
    """
    照合対象2つ、limit指定0
    sizeが0にセットされたクエリが返却されること
    """
    query_body = {"q0": {"query": "hypotheticalprotein", "limit": 0},
                  "q1": {"query": "(2Fe-2S) ferredoxin", "limit": 0}}
    result = EsAccessor.gen_reconcile_query(query_body)
    expected = [
        {
            "query": {
                "bool": {
                    "must": [
                        {
                            "bool": {
                                "should": [
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_before"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "hypotheticalprotein"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_after"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "hypotheticalprotein"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_before"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "hypotheticalprotein",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_after"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "hypotheticalprotein",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                ]
                            }
                        }
                    ],
                    "should": [
                        {
                            "multi_match": {
                                "query": "1",
                                "type": "most_fields",
                                "fields": [
                                    "guideline_PN001",
                                    "guideline_PN002",
                                    "guideline_PN003",
                                    "guideline_PN004",
                                    "guideline_PN005",
                                    "guideline_PN006",
                                    "guideline_PN007",
                                    "guideline_PN011",
                                    "guideline_PN012",
                                    "guideline_PN013",
                                    "guideline_PN014",
                                    "guideline_PN015",
                                    "guideline_PN016",
                                    "guideline_PN017",
                                    "guideline_PN018",
                                    "guideline_PN019",
                                    "guideline_PN020",
                                    "guideline_PN021",
                                    "guideline_PN022",
                                    "guideline_PN024",
                                    "guideline_PN026",
                                    "guideline_PN027",
                                    "guideline_PN028",
                                    "guideline_PN029",
                                    "guideline_PN030",
                                    "guideline_PN034",
                                    "guideline_PN036",
                                    "guideline_PN037",
                                    "guideline_PN038",
                                    "guideline_PN039",
                                    "guideline_PN041",
                                    "guideline_PN042",
                                    "guideline_PN043",
                                    "guideline_PN047",
                                    "guideline_PN048",
                                    "guideline_PN049",
                                    "guideline_PN050",
                                    "guideline_PN051"
                                ]
                            }
                        }
                    ]
                }
            },
            "profile": "false",
            "size": 0,
            "aggs": {
                "tags": {
                    "terms": {
                        "field": "query_type",
                        "size": 4
                    },
                    "aggs": {
                        "top_tag_hits": {
                            "top_hits": {
                                "size": 0,
                                "sort": [
                                    {
                                        "_score": {
                                            "order": "desc"
                                        }
                                    },
                                    {
                                        "normalized_name": {
                                            "order": "asc"
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        },
        {
            "query": {
                "bool": {
                    "must": [
                        {
                            "bool": {
                                "should": [
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_before"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "(2Fe-2S) ferredoxin"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_after"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "(2Fe-2S) ferredoxin"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_before"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "(2Fe-2S) ferredoxin",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_after"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "(2Fe-2S) ferredoxin",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                ]
                            }
                        }
                    ],
                    "should": [
                        {
                            "multi_match": {
                                "query": "1",
                                "type": "most_fields",
                                "fields": [
                                    "guideline_PN001",
                                    "guideline_PN002",
                                    "guideline_PN003",
                                    "guideline_PN004",
                                    "guideline_PN005",
                                    "guideline_PN006",
                                    "guideline_PN007",
                                    "guideline_PN011",
                                    "guideline_PN012",
                                    "guideline_PN013",
                                    "guideline_PN014",
                                    "guideline_PN015",
                                    "guideline_PN016",
                                    "guideline_PN017",
                                    "guideline_PN018",
                                    "guideline_PN019",
                                    "guideline_PN020",
                                    "guideline_PN021",
                                    "guideline_PN022",
                                    "guideline_PN024",
                                    "guideline_PN026",
                                    "guideline_PN027",
                                    "guideline_PN028",
                                    "guideline_PN029",
                                    "guideline_PN030",
                                    "guideline_PN034",
                                    "guideline_PN036",
                                    "guideline_PN037",
                                    "guideline_PN038",
                                    "guideline_PN039",
                                    "guideline_PN041",
                                    "guideline_PN042",
                                    "guideline_PN043",
                                    "guideline_PN047",
                                    "guideline_PN048",
                                    "guideline_PN049",
                                    "guideline_PN050",
                                    "guideline_PN051"
                                ]
                            }
                        }
                    ]
                }
            },
            "profile": "false",
            "size": 0,
            "aggs": {
                "tags": {
                    "terms": {
                        "field": "query_type",
                        "size": 4
                    },
                    "aggs": {
                        "top_tag_hits": {
                            "top_hits": {
                                "size": 0,
                                "sort": [
                                    {
                                        "_score": {
                                            "order": "desc"
                                        }
                                    },
                                    {
                                        "normalized_name": {
                                            "order": "asc"
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    ]
    assert result == expected


def test_gen_reconcile_multi_query_limit1000():
    """
    照合対象2つ、limit指定1000
    sizeが100にセットされたクエリが返却されること
    """
    query_body = {"q0": {"query": "hypotheticalprotein", "limit": 1000},
                  "q1": {"query": "(2Fe-2S) ferredoxin", "limit": 1000}}
    result = EsAccessor.gen_reconcile_query(query_body)
    expected = [
        {
            "query": {
                "bool": {
                    "must": [
                        {
                            "bool": {
                                "should": [
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_before"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "hypotheticalprotein"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_after"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "hypotheticalprotein"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_before"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "hypotheticalprotein",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_after"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "hypotheticalprotein",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                ]
                            }
                        }
                    ],
                    "should": [
                        {
                            "multi_match": {
                                "query": "1",
                                "type": "most_fields",
                                "fields": [
                                    "guideline_PN001",
                                    "guideline_PN002",
                                    "guideline_PN003",
                                    "guideline_PN004",
                                    "guideline_PN005",
                                    "guideline_PN006",
                                    "guideline_PN007",
                                    "guideline_PN011",
                                    "guideline_PN012",
                                    "guideline_PN013",
                                    "guideline_PN014",
                                    "guideline_PN015",
                                    "guideline_PN016",
                                    "guideline_PN017",
                                    "guideline_PN018",
                                    "guideline_PN019",
                                    "guideline_PN020",
                                    "guideline_PN021",
                                    "guideline_PN022",
                                    "guideline_PN024",
                                    "guideline_PN026",
                                    "guideline_PN027",
                                    "guideline_PN028",
                                    "guideline_PN029",
                                    "guideline_PN030",
                                    "guideline_PN034",
                                    "guideline_PN036",
                                    "guideline_PN037",
                                    "guideline_PN038",
                                    "guideline_PN039",
                                    "guideline_PN041",
                                    "guideline_PN042",
                                    "guideline_PN043",
                                    "guideline_PN047",
                                    "guideline_PN048",
                                    "guideline_PN049",
                                    "guideline_PN050",
                                    "guideline_PN051"
                                ]
                            }
                        }
                    ]
                }
            },
            "profile": "false",
            "size": 0,
            "aggs": {
                "tags": {
                    "terms": {
                        "field": "query_type",
                        "size": 4
                    },
                    "aggs": {
                        "top_tag_hits": {
                            "top_hits": {
                                "size": 100,
                                "sort": [
                                    {
                                        "_score": {
                                            "order": "desc"
                                        }
                                    },
                                    {
                                        "normalized_name": {
                                            "order": "asc"
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        },
        {
            "query": {
                "bool": {
                    "must": [
                        {
                            "bool": {
                                "should": [
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_before"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "(2Fe-2S) ferredoxin"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "term_after"
                                                    }
                                                },
                                                {
                                                    "match": {
                                                        "normalized_name.term": {
                                                            "query": "(2Fe-2S) ferredoxin"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_before"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "(2Fe-2S) ferredoxin",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "bool": {
                                            "must": [
                                                {
                                                    "term": {
                                                        "query_type": "mlt_after"
                                                    }
                                                },
                                                {
                                                    "more_like_this": {
                                                        "fields": [
                                                            "normalized_name.mlt"
                                                        ],
                                                        "like": "(2Fe-2S) ferredoxin",
                                                        "max_query_terms": 100,
                                                        "minimum_should_match": "30%",
                                                        "min_term_freq": 0,
                                                        "min_word_length": 0,
                                                        "max_word_length": 0
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                ]
                            }
                        }
                    ],
                    "should": [
                        {
                            "multi_match": {
                                "query": "1",
                                "type": "most_fields",
                                "fields": [
                                    "guideline_PN001",
                                    "guideline_PN002",
                                    "guideline_PN003",
                                    "guideline_PN004",
                                    "guideline_PN005",
                                    "guideline_PN006",
                                    "guideline_PN007",
                                    "guideline_PN011",
                                    "guideline_PN012",
                                    "guideline_PN013",
                                    "guideline_PN014",
                                    "guideline_PN015",
                                    "guideline_PN016",
                                    "guideline_PN017",
                                    "guideline_PN018",
                                    "guideline_PN019",
                                    "guideline_PN020",
                                    "guideline_PN021",
                                    "guideline_PN022",
                                    "guideline_PN024",
                                    "guideline_PN026",
                                    "guideline_PN027",
                                    "guideline_PN028",
                                    "guideline_PN029",
                                    "guideline_PN030",
                                    "guideline_PN034",
                                    "guideline_PN036",
                                    "guideline_PN037",
                                    "guideline_PN038",
                                    "guideline_PN039",
                                    "guideline_PN041",
                                    "guideline_PN042",
                                    "guideline_PN043",
                                    "guideline_PN047",
                                    "guideline_PN048",
                                    "guideline_PN049",
                                    "guideline_PN050",
                                    "guideline_PN051"
                                ]
                            }
                        }
                    ]
                }
            },
            "profile": "false",
            "size": 0,
            "aggs": {
                "tags": {
                    "terms": {
                        "field": "query_type",
                        "size": 4
                    },
                    "aggs": {
                        "top_tag_hits": {
                            "top_hits": {
                                "size": 100,
                                "sort": [
                                    {
                                        "_score": {
                                            "order": "desc"
                                        }
                                    },
                                    {
                                        "normalized_name": {
                                            "order": "asc"
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    ]
    assert result == expected


def test_gen_reconcile_query_empty():
    """
    クエリの内容が空
    空のリストが返却されること
    """
    query_body = {}
    result = EsAccessor.gen_reconcile_query(query_body)
    expected = []
    assert result == expected


def test_gen_reconcile_single_query_limit_str():
    """
    limit値に文字列
    空のリストが返却されること
    """
    query_body = {"q0": {"query": "hypotheticalprotein", "limit": "three"}}
    result = EsAccessor.gen_reconcile_query(query_body)
    expected = []
    assert result == expected
