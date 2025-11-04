#!/bin/bash
#################################################
#環境セットアップ用スクリプト（ETLサーバー）
#第一引数：秘密鍵パス or 0
#※0の場合、秘密鍵の配置をスキップ
#################################################

echo "=====ETLサーバーのセットアップを開始します。====="

echo "現在のタイムゾーんを表示します。"
date

echo "タイムゾーンをAsia/Tokyoに変更します。"
sudo timedatectl set-timezone Asia/Tokyo

echo "変更後のタイムゾーんを表示します。"
date

cd  /home/ec2-user
mkdir cert
echo "/home/ec2-user/certディレクトリ作成完了"

#/home/ec2-user/certディレクトリ作成
if [ -d "/home/ec2-user/cert" ]; then
    echo "/home/ec2-user/certが存在するため作成をスキップします。";
else
    mkdir cert
    echo "/home/ec2-user/certディレクトリの作成が完了しました。"
fi

if [ "$1" -eq 0 ]; then
    echo "証明書配置処理をスキップします。"
else
    if [ -f "$1" ]; then
        mv "$1" /home/ec2-user/cert/
        echo "証明書配置が完了しました。"

        chmod 600 /home/ec2-user/cert/*
        chmod "証明書の権限を600に変更しました。"

    else
        echo "証明書が存在しません。"
        echo "証明書配置処理が失敗しました。"
    fi
fi

#/home/ec2-user/receiveディレクトリ作成
if [ -d "/home/ec2-user/receive" ]; then
    echo "/home/ec2-user/receiveが存在するため作成をスキップします。";
else
    mkdir receive
    echo "/home/ec2-user/receiveディレクトリの作成が完了しました。"
fi

#/home/ec2-user/etlディレクトリ作成
if [ -d "/home/ec2-user/etl" ]; then
    echo "/home/ec2-user/etlが存在するため作成をスキップします。";
else
    mkdir etl
    echo "/home/ec2-user/etlディレクトリの作成が完了しました。"
fi

#/home/ec2-user/etl/logディレクトリ作成
if [ -d "/home/ec2-user/etl/log" ]; then
    echo "/home/ec2-user/etl/logが存在するため作成をスキップします。";
else
    cd  /home/ec2-user/etl
    mkdir log
    echo "/home/ec2-user/etl/logディレクトリの作成が完了しました。"
fi

#/home/ec2-user/etl/log/script.log作成
if [ -f "/home/ec2-user/etl/log/script.log" ]; then
    echo "/home/ec2-user/etl/log/script.logが存在するため作成をスキップします。";
else
    cd  /home/ec2-user/etl/log
    touch script.log
    echo "/home/ec2-user/etl/log/script.logの作成が完了しました。"
fi

#/home/ec2-user/etl/log/error.log作成
if [ -f "/home/ec2-user/etl/log/error.log" ]; then
    echo "/home/ec2-user/etl/log/error.logが存在するため作成をスキップします。";
else
    cd  /home/ec2-user/etl/log
    touch error.log
    echo "/home/ec2-user/etl/log/error.logの作成が完了しました。"
fi

#gitをインストール
sudo dnf update -y
sudo dnf install -y git

#プログラムをgit clone
cd /home/ec2-user/etl/
git clone --branch main --single-branch https://github.com/SatoHiroto526/DataPipeLineTemplate.git temp_repo
mv temp_repo/* temp_repo/.[!.]* .
rm -rf temp_repo

#プログラム権限変更
chmod 777 /home/ec2-user/etl/script/ec2tos3/*
chmod 777 /home/ec2-user/etl/script/kickGlueCrawler/*

echo "=====ETLサーバーのセットアップが完了しました。====="