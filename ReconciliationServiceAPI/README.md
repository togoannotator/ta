# 利用方法

## 設定ファイルの更新
### 1. docker-compose.ymlを開き、hostの値をElasticsearchのIPアドレスに更新する
　※ TogoAnnotator の docker-compose を同一マシン上で立ち上げる場合は変更不要。

```yaml
    build:
      context: .
      args:
        host: "localhost" # ElasticsearchのIPアドレスに書き換える
```

## 2. ビルド
```shell
docker-compose build
```

## 3. 起動
```shell
docker-compose up
```



# 開発時
## Pythonのインストール
### 1. Pythonインストーラの取得
Windows用のPythonインストーラは以下のサイトからダウンロード可能。( 64bit用のPythonインストーラを取得すること。)
https://www.python.org/downloads/windows/

### 2. Pythonインストーラを実行
以下のチェックを必ず入れてから「Install Now」を押下。

* 「Install Launcher for all users(recommended)」
* 「Add Python 3.8 to PATH」

### 3. 「Setup was successful」と表示されたらインストール完了。

### 4. Pythonが実行可能になっているかどうか、コマンドプロンプトから以下のコマンドを実行することで確認できる。

```
python --version
```

実行後、 Python 3.8.2 のようにPythonのバージョンが表示されればOK。
そうでない場合は、上記のインストール手順を見直すこと。

## Pyenvのインストール
### 1. コマンドプロンプトを開き、pipを最新化する。
```
 python -m pip install --upgrade pip
```

### 2. pip経由で、pyenvをインストールする。

```
python -m pip install pyenv-win --target %USERPROFILE%/.pyenv
```

※%USERPROFILE%は、Windowsであれば通常 C:\Users\username となる。
※インストールに失敗する場合は、コメント欄を参照。

### 3. 環境変数へパスを追加する

```
 setx PYENV_WIN_PATH "%USERPROFILE%\.pyenv\pyenv-win"
```

Windowsメニューから環境変数の設定ダイアログを開き、環境変数に以下を追加する。
正し、"Pythonのインストール"で設定された、PythonのPATHよりも前に設定する必要がある。

* 追加する変数：PATH
* 追加する内容：
  * %PYENV_WIN_PATH%\bin
  * %PYENV_WIN_PATH%\shims

### 4. 利用できるPythonを一覧で確認する。

```
pyenv install --list
```

### 5. 切り替えたいバージョンのPythonをインストールする。(例：バージョン3.9.2)

```
pyenv install 3.9.2
```

### 6. 使用するバージョンのPythonに切り替える。

```
pyenv local 3.9.2
pyenv rehash
```

pyenv local {python-version} を実行したディレクトリの配下に、".python-version"ファイルが自動で作成され、そのディレクトリ内だけPythonのバージョンを切り替えることができる。
代わりに pyenv global {python-version} とすると、そのユーザーの環境全体が指定されたPythonのバージョンに切り替わる。

### 7. Pyenvのコマンドで、Pythonのバージョンが指定のものになっていることを確認する。

```
pyenv versions
```

上記コマンドで、今までPyenvでインストールしたPythonのバージョンのリストが表示され、指定したバージョンに "*" がつく。


### 8. Pythonのバージョンが切り替わっていることを確認する。

```
python --version
```

もし、Pythonのバージョンが指定したものに切り替わらない場合は、以下を確認すること。

* 環境変数の順番
* pyenv rehash がエラーなく実行できているか
* 意図していないところに、".python-version"ファイルがないか

## Poetryのインストール
### 1. PowerShellを開き、以下のコマンドでPoetryをインストールする。

```
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py -UseBasicParsing).Content | python
```

### 2. Poetryのパスを追加する。

```
setx POETRY_PATH "%USERPROFILE%\.poetry"
```

Windowsメニューから環境変数の設定ダイアログを開き、環境変数に以下を追加する。

* 追加する変数：PATH
* 追加する内容：%POETRY_PATH%\bin

### 3. Poetryのパスが通ったことを確認する。

```
poetry --version
```

### 4. Poetryの設定を変更し、".venv"フォルダでモジュール管理するようにする。

```
poetry config virtualenvs.in-project true
```

この設定をすると、各エディタでモジュールのインポートエラーになることを防ぐことができる。

### 5. ライブラリをインストールする。

```
poetry install
```


### 6. APIサーバの起動
```
poetry run python /path/to/server.py
```

### 7. ユニットテストの実行
```
poetry run pytest --cov=src --cov-config=.coveragerc
```
