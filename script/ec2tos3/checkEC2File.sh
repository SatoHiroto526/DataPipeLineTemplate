#!/bin/bash
#################################################
#EC2ファイル監視ジョブ
#EC2に特定のファイルが到着しているか監視する
#第一引数:スクリプトログフルパス
#第二引数:標準エラーログフルパス
#第三引数:プロパティファイルのフルパス
#第四引数:監視時間間隔(秒)
#第五引数:総監視時間(秒)
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

# 監視間隔(秒)
INTERVAL="$4"
# 総監視時間(秒)
MONITORING_TIME="$5"
# フラグ定義(1かそれ以外かを判定)
FLAG=1

# プロパティファイルの情報を変数化
# 監視対象ファイルフルパス(受領ディレクトリ+ファイル名)
FILE_PATH="${file_path//$'\r'/}"
# 監視対象サーバーがETL処理を兼ねるかどうかの判定フラグ
# 1の場合は監視対象サーバーがETL処理を兼ねる(1台のマシンでファイル受領とETL処理を兼ねる)
TRANSFER_IS_ETL_FLAG="${transfer_is_etl_flag//$'\r'/}"
# メタデータ受信フラグ
# 1の場合メタデータ受信
METADATA_FLAG="${metadata_flag//$'\r'/}"
# EC2ファイル受領ディレクトリ+メタデータ名
METADATA_PATH="${metadata_path//$'\r'/}"
# ファイル受領サーバーのIPアドレス
TRANSFER_SERVER="${transfer_server//$'\r'/}"
# ファイル受領サーバーのログイン用ユーザー名
USERNAME="${username//$'\r'/}"
# ファイル受領サーバーのログイン用秘密鍵
PEMKEY="${pemkey//$'\r'/}"

echo "===== $(date '+%Y-%m-%d %H:%M:%S') : EC2ファイル監視ジョブを開始します。 ===== "
echo "-I:処理対象ファイル:${FILE_PATH}" >&1
if [ "${TRANSFER_IS_ETL_FLAG}" -eq "${FLAG}" ]; then
    # 監視対象サーバーがETL処理を兼ねる場合
    echo "-I:監視対象サーバーがETL処理を兼ねる場合の処理を実行します。" >&1
else
    # 監視対象サーバーとETLサーバーを分ける場合
    echo "-I:監視対象サーバーがETL処理を分ける場合の処理を実行します。" >&1
fi

# ファイル監視実行関数
# リターンコード:0⇒ファイル受領確認
# リターンコード:1⇒ファイル受領未確認
# 第一引数:TRANSFER_IS_ETL_FLAG
# 第二引数:FILE_PATH or METADATA_PATH
# 第三引数:PEMKEY
# 第四引数:USERNAME
# 第五引数:TRANSFER_SERVER
function checkFile () {
    if [ "$1" -eq "${FLAG}" ]; then 
        # 監視対象サーバーがETL処理を兼ねる場合
        [ -f "$2" ]
        return $?
    else
        # 監視対象サーバーとETL処理分ける場合
        # "[ -f \"$2\" ]":外側はダブルクオート、内側はシングルクオート(エスケープ)
        ssh -i "$3" -o StrictHostKeyChecking=no "$4@$5" "[ -f \"$2\" ]"
        return $?
    fi
}

# ファイル監視ステータスコードを初期化(1:ファイル到着未確認)
CHECK_FILE_RESULT=1
# メタデータ監視ステータスコードを初期化(1:ファイル到着未確認)
CHECK_METADATA_RESULT=1

# ファイル監視開始
echo "-I:${INTERVAL}秒間隔で、最大${MONITORING_TIME}秒のファイル監視を実行します。" >&1
for (( i=0; i<=$MONITORING_TIME; i+=$INTERVAL ))
do
    # ファイル監視実行
    checkFile "${TRANSFER_IS_ETL_FLAG}" "${FILE_PATH}" "${PEMKEY}" "${USERNAME}" "${TRANSFER_SERVER}" 
    CHECK_FILE_RESULT=$?

    # メタデータ受信有無をチェック
    if [ "${METADATA_FLAG}" -eq "${FLAG}" ]; then
        checkFile "${TRANSFER_IS_ETL_FLAG}" "${METADATA_PATH}" "${PEMKEY}" "${USERNAME}" "${TRANSFER_SERVER}" 
        CHECK_METADATA_RESULT=$?
    else
        CHECK_METADATA_RESULT=0
    fi


    if [ "${CHECK_FILE_RESULT}" -eq 0 ] && [ "${CHECK_METADATA_RESULT}" -eq 0 ]; then 
        echo "-I:ファイル監視ステータスコード=${CHECK_FILE_RESULT}, メタデータ監視ステータスコード=${CHECK_METADATA_RESULT}" >&1
        echo "-I:受領を確認しました。(ファイル監視経過時間:${i}秒)" >&1
        echo "===== $(date '+%Y-%m-%d %H:%M:%S') : EC2ファイル監視ジョブを正常終了します。 ===== " >&1
        exit 0
    else
        echo "-I:ファイル監視ステータスコード=${CHECK_FILE_RESULT}, メタデータ監視ステータスコード=${CHECK_METADATA_RESULT}" >&1
        echo "-I:受領を確認できません。リトライします。(ファイル監視経過時間:${i}秒)" >&1
        # # 監視間隔(秒)スリープ
        sleep "${INTERVAL}"
    fi
done

# ファイル監視タイムアウト(異常終了)
echo "-E:時限内にファイル受領を確認できませんでした。" >&1
echo "===== $(date '+%Y-%m-%d %H:%M:%S') : EC2ファイル監視ジョブを異常終了します。 ===== " >&1
exit 1