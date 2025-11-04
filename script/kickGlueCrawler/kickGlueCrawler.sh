#!/bin/bash
#################################################
#Glueクローラー起動ジョブ
#特定のGlueクローラーを起動する
#第一引数:スクリプトログフルパス
#第二引数:標準エラーログフルパス
#第三引数:プロパティファイルのフルパス
#################################################

# スクリプトログ
SCRIPT_LOG="$1"
# エラーログ(標準エラーログの吐き出し先)
ERROR_LOG="$2"

# ログ出力先の振り分けを定義
# 1:stdout(標準出力):独自定義のメッセージはすべて標準出力定義
# 2:stderr(標準エラー出力)
# >>:追記(>:上書き)
exec 1>>"$SCRIPT_LOG"
exec 2>>"$ERROR_LOG"

# プロパティファイル読み込み
source "$3"

# プロパティファイルの情報を変数化
# クローラー名
CRAWLER_NAME="${crawler_name//$'\r'/}"
# リージョン
REGION="${region//$'\r'/}"

echo "===== $(date '+%Y-%m-%d %H:%M:%S') : Glueクローラー起動ジョブを開始します。 ===== " >&1
echo "-I:起動対象クローラー:${CRAWLER_NAME}" >&1

# Glueクローラー起動
echo "-I:Glueクローラーを起動します。" >&1
aws glue start-crawler --name "${CRAWLER_NAME}" --region "${REGION}"

# ステータス定義
READY="READY"
STOPPING="STOPPING"

# 結果定義
SUCCEEDED="SUCCEEDED"
FAILED="FAILED"
CANCELLED="CANCELLED"

# ステータス監視
echo "-I:クローラーのステータス監視を開始します。" >&1
while true; do
    STATE=$(aws glue get-crawler --name "$CRAWLER_NAME" --query "Crawler.State" --output text --region "$REGION")
    LAST_CRAWL_STATES=$(aws glue get-crawler --name "$CRAWLER_NAME" --query "Crawler.LastCrawl.Status" --output text --region "$REGION")
    
    echo "-i:ステータス=${STATE},ラストクロールステータス=${LAST_CRAWL_STATES}"

    if [ "${STATE}" = "${READY}" ]; then

        if [ "${LAST_CRAWL_STATES}" = "${SUCCEEDED}" ]; then
            echo "-I:クローリングが正常終了しました。" >&1
            echo "===== $(date '+%Y-%m-%d %H:%M:%S') : Glueクローラー起動ジョブを正常終了します。 ===== " >&1
            exit 0
        elif [ "${LAST_CRAWL_STATES}" = "${FAILED}" ]; then
            echo "-E:クローリングが異常終了しました。" >&1
            echo "===== $(date '+%Y-%m-%d %H:%M:%S') : Glueクローラー起動ジョブを異常終了します。 ===== " >&1
            exit 1
        elif [ "${LAST_CRAWL_STATES}" = "${CANCELLED}" ]; then
            echo "-E:クローリングがキャンセルされました。" >&1
            echo "===== $(date '+%Y-%m-%d %H:%M:%S') : Glueクローラー起動ジョブを異常終了します。 ===== " >&1
            exit 1
        else
            echo "-E:クローリングが異常終了しました。" >&1
            echo "===== $(date '+%Y-%m-%d %H:%M:%S') : Glueクローラー起動ジョブを異常終了します。 ===== " >&1
            exit 1
        fi

    elif [ "${STATE}" = "${STOPPING}" ]; then
        echo "-I:クローリングが停止しています。" >&1
        echo "-I:クローラーのステータス監視を続けます。" >&1
    else
        echo "-I:クローリングが起動しています。" >&1
        echo "-I:クローラーのステータス監視を続けます。" >&1
    fi

    sleep 5

done