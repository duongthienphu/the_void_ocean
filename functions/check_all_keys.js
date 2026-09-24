const { GoogleGenAI } = require("@google/genai");

// Dán danh sách các API Key bạn đang lưu trong Firestore vào đây để test
const KEYS_TO_CHECK = [
  { id: "Key 001", key: "" },
  { id: "Key 002", key: "" },

];

async function testKeys() {
  console.log(`=== BẮT ĐẦU KIỂM TRA ${KEYS_TO_CHECK.length} KEYS ===\n`);

  for (const item of KEYS_TO_CHECK) {
    try {
      const ai = new GoogleGenAI({ apiKey: item.key });
      const res = await ai.models.generateContent({
        model: "gemma-4-26b-a4b-it",
        contents: "ping",
      });
      console.log(`✅ [${item.id}]: SỐNG TỐT -> Phản hồi: ${res.text.trim()}`);
    } catch (err) {
      console.log(`❌ [${item.id}]: LỖI ->`, err.status || err.code || "", err.message || err);
    }
  }
  console.log("\n=== HOÀN TẤT KIỂM TRA ===");
}

testKeys();