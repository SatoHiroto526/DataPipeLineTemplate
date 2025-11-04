#!/bin/bash
#################################################
#EC2→S3ファイル転送ジョブ
#EC2の特定のファイルをS3に転送する
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

# 転送先S3情報
S3_BUCKET="${s3bucket//$'\r'/}"
S3_PREFIX="${s3preffix//$'\r'/}"
S3_SUFFIX="${s3suffix//$'\r'/}"

echo "===== $(date '+%Y-%m-%d %H:%M:%S') : EC2→S3ファイル転送ジョブを開始します。 ===== "
echo "-I:処理対象ファイル:${FILE_PATH}" >&1
if [ "${TRANSFER_IS_ETL_FLAG}" -eq "${FLAG}" ]; then
    # 監視対象サーバーがETL処理を兼ねる場合
    echo "-I:転送元サーバーがETL処理を兼ねる場合の処理を実行します。" >&1
else
    # 監視対象サーバーとETLサーバーを分ける場合
    echo "-I:転送元サーバーとETL処理用サーバーを分ける場合の処理を実行します。" >&1
fi

# ファイル転送実行関数
# S3バケット/プレフィックス/サフィックス/YYYYmmdd/ファイル名の形式でロード
# リターンコード:0⇒ファイル受領確認
# リターンコード:1⇒ファイル受領未確認
# 第一引数:TRANSFER_IS_ETL_FLAG
# 第二引数:FILE_PATH or METADATA_PATH
# 第三引数:S3_BUCKET
# 第四引数:S3_PREFIX
# 第五引数:S3_SUFFIX
# 第六引数:FILES_OR_METADATAS
# 第七引数:PEMKEY
# 第八引数:USERNAME
# 第九引数:TRANSFER_SERVER
function s3cp () {
    # S3パス組み立て1
    S3PATH="$3$4$5"
    
    #/files/
    FILES=/files
    #/metadatas/
    METADATAS=/metadatas
    # 以下、Apache Hive形式でS3に格納
    # year=y
    YEAR="/year=$(date +%Y)"
    # month=m
    MONTH="/month=$(date +%m)"
    # day=d
    DAY="/day=$(date +%d)/"
    # Hive形式のパス作成
    HIVE_PATH="$YEAR$MONTH$DAY"
    
    # /files/なのか/metadatasなのか判定
    if [ "$6" -eq "${FLAG}" ]; then
        # S3パス組み立て2-1
        S3PATH+="$FILES$HIVE_PATH"
    else
        # S3パス組み立て2-2
        S3PATH+="$METADATAS$HIVE_PATH"
    fi

    if [ "$1" -eq "${FLAG}" ]; then
        aws s3 cp "$2" "${S3PATH}"
        return $? 
    else
        ssh -i "$7" -o StrictHostKeyChecking=no "$8@$9" "aws s3 cp" "$2" "${S3PATH}"
        return $?
    fi
} 

#ファイル転送ステータスコードを初期化
TRANSFER_FILE_RESULT=0
#メタデータ転送ステータスコードを初期化
TRANSFER_METADATA_RESULT=0

# ファイル転送開始
echo "-I:S3へのファイル転送を実行します。" >&1

# S3の/files/に転送するか、/metadatas/に転送するか
# /files/に転送する場合は1 ※初期値:1
# /metadatas/転送する場合は0に切り替え
FILES_OR_METADATAS=1

# ファイル転送実行
s3cp "${TRANSFER_IS_ETL_FLAG}" "${FILE_PATH}" "${S3_BUCKET}" "${S3_PREFIX}" "${S3_SUFFIX}" "${FILES_OR_METADATAS}" "${PEMKEY}" "${USERNAME}" "${TRANSFER_SERVER}" 
TRANSFER_FILE_RESULT=$?

if [ "${METADATA_FLAG}" -eq "${FLAG}" ]; then
    # 0に切り替え
    FILES_OR_METADATAS=0

    # メタデータ転送実行
    s3cp "${TRANSFER_IS_ETL_FLAG}" "${METADATA_PATH}" "${S3_BUCKET}" "${S3_PREFIX}" "${S3_SUFFIX}" "${FILES_OR_METADATAS}" "${PEMKEY}" "${USERNAME}" "${TRANSFER_SERVER}" 
    TRANSFER_METADATA_RESULT=$?
fi

if [ "${TRANSFER_FILE_RESULT}" -eq 0 ] && [ "${TRANSFER_METADATA_RESULT}" -eq 0 ]; then
    # ファイル転送、メタデータ転送ともに正常終了
    echo "-I:ファイル転送ステータスコード=${TRANSFER_FILE_RESULT}, メタデータ転送ステータスコード=${TRANSFER_METADATA_RESULT}" >&1
    echo "-I:S3への転送が完了しました。" >&1
    echo "===== $(date '+%Y-%m-%d %H:%M:%S') : EC2→S3ファイル転送ジョブを正常終了します。 ===== " >&1
    exit 0
else
    # ファイル転送、メタデータ転送どちらか／ともに異常終了
    echo "-I:ファイル転送ステータスコード=${TRANSFER_FILE_RESULT}, メタデータ転送ステータスコード=${TRANSFER_METADATA_RESULT}" >&1
    echo "-I:S3への転送が失敗しました。" >&1
    echo "===== $(date '+%Y-%m-%d %H:%M:%S') : EC2→S3ファイル転送ジョブを異常終了します。 ===== " >&1
    exit 1
fi