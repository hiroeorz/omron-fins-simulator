# OMRON FINS SIMULATOR

## これは何

これはRubyの動作するPCを仮想PLCとして動作させるためのスクリプトです。
PLCとFINSプロトコルを通じて通信するプログラムのデバッグのために実装しました。

起動と同時に指定ポート(デフォルト:9600)でUDPソケットをListenし、FINSプロトコルによる要求に対して応答を返します。
現時点ではDMエリアの取得と書き込み、及び日時の取得にのみ対応しています。またTCPには対応しておりません。

## 実行環境

* `Ruby 1.8` 以上。Linux, MacOSXで検証済み。Windowsでも動作すると思います。
* 本スクリプトを稼働させるPCと通信するPCがUDPの9600番ポート（または `--port` で指定したポート）で、お互いに通信可能なネットワーク環境であること。

## インストール

このプロジェクトを手元に `git clone` してください。

```
$ git clone https://github.com/hiroeorz/omron-fins-simulator.git
```

実行に必要なファイルは `omron_plc.rb` のみですので、これをそのまま実行するか、または適当なディレクトリにコピーして実行してください。

```
$ ruby omron_plc.rb --address=<自身のIPアドレス> --port=<待ち受けポート番号>
```


実行例:

```
$ cd omron-fins-simulator
$ ruby omron_plc.rb --address=192.168.0.6 --port=9600
```

その他、幾つかのオプションがあります。

```
$ ruby omron_plc.rb --address=192.168.0.6 --port=9600 --count_up_dm=5095 --countup_interval=5 --load_file=/tmp/dm.yaml
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

### 対話形式での値の設定、取得

起動すると、指定ポートでUDPパケットの受付を開始し、コンソール上では入力待ちの状態となります。

```
$ ruby omron_plc.rb --address=192.168.0.6 --port=9600

Loading /tmp/test.yaml...done
UDP Socket bind to host:192.168.0.6, port:9600.

----------------------------------------------------
PLC SIMULATOR SYSTEM
----------------------------------------------------
SET DM COMMAND     : > set <dm number>, <value>
GET DM COMMAND     : > get <dm number>
GET DM LIST COMMAND: > get_list <dm number>, <count>
EXIT COMMAND       : > exit
----------------------------------------------------

> 
```

上記のように、 `>` が表示されると、幾つかのコマンドが使用可能となります。

#### DMエリアへの値の設定

```
> set <dm number>, <value>
```

#### DMエリアの値の読み込み

```
> get <dm number>
<値の表示>
```

#### 複数DMエリアの値の一括読み込み

```
> get_list <dm number>, <count>
<DM番地1番目> : 値
<DM番地2番目> : 値
<DM番地3番目> : 値
```

#### プログラムの終了

```
> exit
```

#### 実行例

```
$ ruby omron_plc.rb --address=192.168.0.6 --port=9600

Loading /tmp/test.yaml...done
UDP Socket bind to host:172.16.15.35, port:9600.

----------------------------------------------------
PLC SIMULATOR SYSTEM
----------------------------------------------------
SET DM COMMAND     : > set <dm number>, <value>
GET DM COMMAND     : > get <dm number>
GET DM LIST COMMAND: > get_list <dm number>, <count>
EXIT COMMAND       : > exit
----------------------------------------------------

> 
> set 1, 100
ok

> set 2, 200
ok

> set 3, 300
ok

> get_list 1, 3
1 : 100
2 : 200
3 : 300

> exit

$
```
