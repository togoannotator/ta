import server


def test_make_manifest_response():
    """
    パラメータ指定なし
    サービス名が返却されること
    """
    result = server.make_manifest_response()
    expected = {
        "name": "TogoAnnotator",
        "identifierSpace": "",
        "schemaSpace": "",
        "view": {
            "url": ""
        }
    }
    assert result == expected, "result=" + str(result)
