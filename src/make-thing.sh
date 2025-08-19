#!/bin/bash

# このスクリプトは docs/要件仕様.md に基づき、1000件のThingを作成します。
#
# - Thing名: thing-v00001 ~ thing-v01000
# - Shadow:
#   - thing-v00001 ~ thing-v00800: reported.owned は true
#   - thing-v00801 ~ thing-v01000: reported.owned は false

# Thingに紐付けるポリシーを作成します。
# このポリシーは、'thing-v'で始まる名前のThingに対してのみShadowの取得と更新を許可します。
# これにより、意図しないThingへのアクセスを防ぎます。
POLICY_NAME="thing-policy"
POLICY_DOCUMENT='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iot:GetThingShadow",
        "iot:UpdateThingShadow"
      ],
      "Resource": "arn:aws:iot:*:*:thing/thing-v*"
    }
  ]
}'

# AWS IoTポリシーが存在しない場合のみ作成します。
aws iot get-policy --policy-name "$POLICY_NAME" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ポリシー '$POLICY_NAME' を作成しています..."
  aws iot create-policy --policy-name "$POLICY_NAME" --policy-document "$POLICY_DOCUMENT"
else
  echo "ポリシー '$POLICY_NAME' は既に存在します。"
fi

# 出力用のディレクトリを作成します。'-p'オプションで、存在しない場合のみ作成します。
# スクリプトはプロジェクトルートから実行されることを想定しています。
OUTPUT_DIR="src/output"
mkdir -p "$OUTPUT_DIR"
echo "出力先ディレクトリ '$OUTPUT_DIR' を確認しました。"

# 1から1000までのループでThingを作成し、シャドウを更新します。
for i in $(seq 1 1000)
do
  # 5桁のゼロ埋め形式でThing番号を生成します。(例: 1 -> 00001)
  THING_NUM=$(printf "%05d" $i)
  THING_NAME="thing-v${THING_NUM}"
  USER_ID="u${THING_NUM}"
  CAR_ID="v${THING_NUM}"

  # Thing番号に基づいてシャドウの 'owned' の値を決定します。
  # 要件に従い、800番目まではtrue、それ以降はfalseとします。
  if [ $i -le 800 ]; then
    OWNED=true
  else
    OWNED=false
  fi

  # JSON形式のシャドウペイロードを生成します。
  # cat <<EOF はヒアドキュメントと呼ばれ、複数行の文字列を効率的に変数に格納します。
  SHADOW_PAYLOAD=$(cat <<EOF
{
  "state": {
    "desired": {
      "userId": "${USER_ID}",
      "carId": "${CAR_ID}",
      "owned": ${OWNED}
    },
    "reported": {
      "userId": "${USER_ID}",
      "carId": "${CAR_ID}",
      "owned": ${OWNED}
    }
  }
}
EOF
)

  # 出力ファイル名を定義します。
  OUTFILE="${OUTPUT_DIR}/${THING_NAME}-shadow.json"

  # Thingが存在しない場合のみ作成します。
  aws iot describe-thing --thing-name "$THING_NAME" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Thing '$THING_NAME' を作成しています..."
    aws iot create-thing --thing-name "$THING_NAME"
  else
    echo "Thing '$THING_NAME' は既に存在します。"
  fi

  # Thingのシャドウを更新し、レスポンスを指定したファイルに出力します。
  echo "Shadow for '$THING_NAME' を更新しています..."
  aws iot-data update-thing-shadow --thing-name "$THING_NAME"  --cli-binary-format raw-in-base64-out --payload "$SHADOW_PAYLOAD" "$OUTFILE"
  echo "シャドウのレスポンスを $OUTFILE に保存しました。"
done

echo "すべての処理が完了しました。"