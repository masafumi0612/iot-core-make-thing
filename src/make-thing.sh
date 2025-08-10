#!/bin/bash

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

# make-thing.jsonからThingの情報を読み込み、ループ処理でThingを作成およびシャドウを更新します。
# jqコマンドを使用してJSONファイルをパースしています。

jq -c '.[]' make-thing.json | while read -r item; do
  THING_NAME=$(echo "$item" | jq -r '.thingName')
  SHADOW_PAYLOAD=$(echo "$item" | jq -c '.shadow')

  # Thingが存在しない場合のみ作成します。
  aws iot describe-thing --thing-name "$THING_NAME" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Thing '$THING_NAME' を作成しています..."
    aws iot create-thing --thing-name "$THING_NAME"

    # Thingのシャドウを更新します。
    echo "'Shadow for $THING_NAME' を更新しています..."
    aws iot-data update-thing-shadow --thing-name "$THING_NAME" --payload "$SHADOW_PAYLOAD"
  else
    echo "Thing '$THING_NAME' は既に存在します。"
  fi
done

echo "\nすべての処理が完了しました。"

