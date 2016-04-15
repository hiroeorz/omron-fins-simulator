# OMRON FINS SIMULATOR

## これは何

これはRubyの動作するPCを仮想PLCとして動作させるためのスクリプトです。
PLCとFINSプロトコルを通じて通信するプログラムのデバッグのために実装しました。

## 実行環境

* `Ruby 1.8` 以上。Linux, MacOSXで検証済み。Windowsでも動作すると思います。
* 本スクリプトを稼働させるPCと通信するPCがUDPの9600番ポート（または `--port` で指定したポート）で、お互いに通信可能なネットワーク環境であること。

## インストール

このプロジェクトを手元に `git clone` してください。

```
$ https://github.com/hiroeorz/omron-fins-simulator.git
```

実行に必要なファイルは `omron_plc.rb` のみですので、これをそのまま実行するか、または適当なディレクトリにコピーして実行してください。

```
$ ruby omron_plc.rb --address=<自身のIPアドレス> --port=<待ち受けポート番号>
```


実行例:

```
$ cd omron-fins-simulator
$ ruby omron_plc.rb --address=172.16.15.35 --port=9600
```

その他、幾つかのオプションがあります。

```
$ cd omron-fins-simulator
$ ruby omron_plc.rb --address=172.16.15.35 --port=9600 --count_up_dm=5095 --countup_interval=5 --load_file=/tmp/dm.yaml
```

* `--address` : 自身のIPアドレス。デフォルトは `127.0.0.1`
* `--port` : ポート番号。デフォルトは `9600`
* `--count_up_dm` : 自動カウントアップするDM番号を指定する。カンマ区切りで複数指定できる。
    * 複数指定の例: `--count_up_dm=1,2,3`
* `--countup_interval` : 自動カウントアップするインターバルを指定。デフォルトは5秒
* `--load_file` : 起動時に読み込むDMの設定ファイル。指定しなければ、全てのDMは初期状態で `0`
    * 設定ファイルのフォーマットはYAMLで、キーがDM番号、値がDMの値
        ``` 
        3: 0
        100: 11
        101: 21
        102: 0xff
        103: 0x10
        ``` 

