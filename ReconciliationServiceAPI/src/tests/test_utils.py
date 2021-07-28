from utils import utils
import numpy as np


def test_normalization_score_limit3():
    """
    照合対象1つ、limit指定3
    query_typeごとに正規化された値が返却されること
    """
    es_scores = {'mlt_before': [96.868, 96.868, 96.868], 'term_before': [31.0, 31.0, 31.0],
                 'mlt_after': [97.02595, 89.62538, 89.62538], 'term_after': [31.0, 31.0, 31.0]}
    result = utils.normalization_score(es_scores)
    expected = {'mlt_before': np.array([0., 0., 0.]), 'term_before': np.array([50., 50., 50.]),
                'mlt_after': np.array([49.99, 25., 25.]), 'term_after': np.array([75., 75., 75.])}
    assert str(result) == str(expected), "result=" + str(result)


def test_normalization_score__illegal_query_type():
    """
    query_typeが不正
    不正なquery_type以外のquery_typeのリストが返却されること
    """
    es_scores = {'illegal_query_type': [96.868, 96.868, 96.868], 'term_before': [31.0, 31.0, 31.0],
                 'mlt_after': [97.02595, 89.62538, 89.62538], 'term_after': [31.0, 31.0, 31.0]}
    result = utils.normalization_score(es_scores)
    expected = {'term_before': np.array([50., 50., 50.]), 'mlt_after': np.array(
        [49.99, 25., 25.]), 'term_after': np.array([75., 75., 75.])}
    assert str(result) == str(expected), "result=" + str(result)
