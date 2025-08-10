import { IoTDataPlaneClient, GetThingShadowCommand } from "@aws-sdk/client-iot-data";

// AWS IoTデータプレーンのクライアントを初期化します。
// リージョンは環境変数やAWS設定ファイルから自動的に取得されます。
const client = new IoTDataPlaneClient({});

/**
 * 指定されたThingのClassic Shadowを取得し、コンソールに出力します。
 * @param thingName Shadowを取得するThingの名前
 */
async function getThingShadow(thingName: string) {
  console.log(`Getting shadow for ${thingName}...`);
  const command = new GetThingShadowCommand({ thingName });

  try {
    const response = await client.send(command);
    if (response.payload) {
      // レスポンスのpayloadはUint8Arrayなので、文字列に変換してからJSONとしてパースします。
      const shadow = JSON.parse(Buffer.from(response.payload).toString());
      console.log(`Shadow for ${thingName}:`);
      console.log(JSON.stringify(shadow, null, 2));
    } else {
      console.log(`No shadow found for ${thingName}.`);
    }
  } catch (error) {
    console.error(`Failed to get shadow for ${thingName}:`, error);
  }
}

/**
 * メイン関数
 * 10個のThingの名前を生成し、それぞれのShadow取得処理を並列で実行します。
 */
async function main() {
  const thingNames: string[] = [];
  for (let i = 1; i <= 10; i++) {
    // Thingの名前をゼロパディングして生成します (e.g., thing-v00001)
    const thingNumber = i.toString().padStart(5, '0');
    thingNames.push(`thing-v${thingNumber}`);
  }

  // すべてのThingに対するShadow取得処理をプロミスの配列として作成します。
  const promises = thingNames.map(getThingShadow);
  
  // Promise.allを使って、すべてのプロミスが完了するのを待ちます。
  // これにより、各ThingのShadow取得が並列で実行されます。
  await Promise.all(promises);

  console.log("\nAll shadow fetch operations completed.");
}

main();
