#!/bin/bash
#################################################
#EC2ファイル削除ジョブ
#EC2に特定のファイルが到着しているか監視する
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

# フラグ定義(1かそれ以外かを判定)
FLAG=1

# プロパティファイルの情報を変数化
# 削除対象ファイルフルパス(受領ディレクトリ+ファイル名)
FILE_PATH="${file_path//$'\r'/}"
# 監視対象サーバーがETL処理を兼ねるかどうかの判定フラグ
# 1の場合はファイル受領サーバーがETL処理を兼ねる(1台のマシンでファイル受領とETL処理を兼ねる)
TRANSFER_IS_ETL_FLAG="${transfer_is_etl_flag//$'\r'/}"
# メタデータ削除フラグ
# 1の場合メタデータ削除
METADATA_FLAG="${metadata_flag//$'\r'/}"
# EC2ファイル受領ディレクトリ+メタデータ名
METADATA_PATH="${metadata_path//$'\r'/}"
# ファイル受領サーバーのIPアドレス
TRANSFER_SERVER="${transfer_server//$'\r'/}"
# ファイル受領サーバーのログイン用ユーザー名
USERNAME="${username//$'\r'/}"
# ファイル受領サーバーのログイン用秘密鍵
PEMKEY="${pemkey//$'\r'/}"

echo "===== $(date '+%Y-%m-%d %H:%M:%S') : EC2ファイル削除ジョブを開始します。 ===== "
echo "-I:削除対象ファイル:${FILE_PATH}" >&1
if [ "${TRANSFER_IS_ETL_FLAG}" -eq "${FLAG}" ]; then
    # ファイル受領サーバーがETL処理を兼ねる場合
    echo "-I:ファイル受領サーバーがETL処理を兼ねるの処理を実行します。" >&1
else
    # 監視対象サーバーとETLサーバーを分ける場合
    echo "-I:ファイル受領サーバーとETL処理を分ける場合の処理を実行します。" >&1
fi

# ファイル削除実行関数
# リターンコード:0⇒ファイル受領確認
# リターンコード:1⇒ファイル受領未確認
# 第一引数:TRANSFER_IS_ETL_FLAG
# 第二引数:FILE_PATH or METADATA_PATH
# 第三引数:PEMKEY
# 第四引数:USERNAME
# 第五引数:TRANSFER_SERVER
function deleteFile () {
    if [ "$1" -eq "${FLAG}" ]; then 
        # ファイル受領サーバーがETL処理を兼ねる場合
        rm -f "$2"
        return $?
    else
        # 監視対象サーバーとETLサーバーを分ける場合
        # "[ -f \"$2\" ]":外側はダブルクオート、内側はシングルクオート(エスケープ)
        ssh -i "$3" -o StrictHostKeyChecking=no "$4@$5" "rm -f \"$2\""
        return $?
    fi
}

# ファイル削除ステータスコードを初期化
DELETE_FILE_RESULT=1
# メタデータ削除ステータスコードを初期化
DELETE_METADATA_RESULT=1

# ファイル削除実行
echo "-I:ファイル削除を実行します。" >&1

deleteFile "${TRANSFER_IS_ETL_FLAG}" "${FILE_PATH}" "${PEMKEY}" "${USERNAME}" "${TRANSFER_SERVER}" 
DELETE_FILE_RESULT=$?

# メタデータ削除有無をチェック
if [ "${METADATA_FLAG}" -eq "${FLAG}" ]; then
    deleteFile "${TRANSFER_IS_ETL_FLAG}" "${METADATA_PATH}" "${PEMKEY}" "${USERNAME}" "${TRANSFER_SERVER}" 
    DELETE_METADATA_RESULT=$?
else
    DELETE_METADATA_RESULT=0
fi

# 削除結果チェック
echo "-I:ファイル削除ステータスコード=${DELETE_FILE_RESULT}, メタデータ削除ステータスコード=${DELETE_METADATA_RESULT}" >&1
if [ "${DELETE_FILE_RESULT}" -eq 0 ] && [ "${DELETE_METADATA_RESULT}" -eq 0 ]; then 
    echo "===== $(date '+%Y-%m-%d %H:%M:%S') : EC2ファイル削除ジョブを正常終了します。 ===== " >&1
    exit 0
else
    echo "===== $(date '+%Y-%m-%d %H:%M:%S') : EC2ファイル削除ジョブを異常終了します。 ===== " >&1
    exit 1
fi