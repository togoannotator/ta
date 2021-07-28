import numpy as np
from sklearn import preprocessing


def normalization_score(es_scores: dict):
    normalized_score = {}
    for query_type in es_scores:
        if query_type not in ['term_after', 'term_before',
                              'mlt_after', 'mlt_before']:
            continue
        if len(es_scores[query_type]) > 0:
            normalized_score[query_type] = np.array(preprocessing.minmax_scale
                                                    (es_scores[query_type]))
        else:
            normalized_score[query_type] = np.array([])

    # [0,25), [25,50), [50,75), [75,100) の区間に調整
    delta = 0.01  # query_typeの境界値でスコアが重複しないための調整値
    if 'term_after' in normalized_score:
        normalized_score['term_after'] = normalized_score['term_after']\
            * (25 - delta) + 75
    if 'term_before' in normalized_score:
        normalized_score['term_before'] = normalized_score['term_before']\
            * (25 - delta) + 50
    if 'mlt_after' in normalized_score:
        normalized_score['mlt_after'] = normalized_score['mlt_after']\
            * (25 - delta) + 25
    if 'mlt_before' in normalized_score:
        normalized_score['mlt_before'] = normalized_score['mlt_before']\
            * (25 - delta)

    return normalized_score
