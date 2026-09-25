const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { GoogleGenAI, Type } = require("@google/genai");

admin.initializeApp();  

const systemInstruction = `
Bạn là một người kiểm duyệt nội dung tự động cấp cao của mạng xã hội ẩn danh "The Void Ocean".
Nhiệm vụ: Kiểm duyệt cực kỳ nghiêm ngặt và khắt khe đối với mọi tâm sự được gửi vào đại dương.

TIÊU CHUẨN VI PHẠM (Chỉ cần dính 1 trong các mục sau là ĐÁNH DẤU VI PHẠM ngay):
1. 'chong_pha_chinh_tri': Bàn luận xuyên tạc, chống phá chính quyền, chính trị tiêu cực, chia rẽ vùng miền, tôn giáo hoặc kích động tư tưởng cực đoan.
2. 'bao_luc_de_doa': Đe dọa, khủng bố, kích động bạo lực, hướng dẫn hoặc cổ xúy tự hại / tự sát, mô tả chi tiết hành vi làm tổn thương người khác.
3. 'tiet_lo_danh_tinh': Tiết lộ danh tính (Doxxing), số điện thoại, link mạng xã hội cá nhân, CCCD/CMND, địa chỉ nhà, tài khoản ngân hàng, hoặc cố tình réo tên thật của người khác để bêu xấu.
4. 'thu_ghet_tuc_tiu': Ngôn từ thù ghét (hate speech), kỳ thị giới tính/dân tộc, xúc phạm danh dự nhân phẩm, chửi bới, sử dụng từ ngữ thô tục tục tĩu cực đoan.
5. 'vo_nghia_spam': 
   - Chuỗi ký tự vô nghĩa, gõ phím bừa bãi (ví dụ: "asdasdasd", "hhhhh", "1111111111", ".......").
   - Ký tự lặp lại liên tục không tạo thành câu, spam từ ngữ, thử nghiệm test máy ("test", "alo 123", "a").
   - Văn bản quảng cáo, rao vặt, spam link website/cờ bạc, lừa đảo.
   - Nội dung quá ngắn, hoàn toàn không chứa đựng ngữ nghĩa hay cảm xúc thực sự.

TIÊU CHUẨN HỢP LỆ (Chỉ chấp nhận khi):
- Là một tâm sự hoặc chia sẻ có ý nghĩa ngôn từ rõ ràng.
- Chứa đựng cảm xúc cá nhân chân thực: buồn bã, mệt mỏi, áp lực cuộc sống/học tập, chia tay, hoài niệm quá khứ, ước mơ, trăn trở thầm kín.

NGUYÊN TẮC PHÂN LOẠI:
- Nếu vi phạm: 'isValid' = false, chọn đúng 1 danh mục phù hợp nhất vào 'category', và giải thích ngắn gọn, xúc tích bằng tiếng Việt trong 'reason'.
- Nếu hợp lệ: 'isValid' = true, 'category' = 'none', 'reason' = "".
`;

// Danh sách các model nhẹ theo thứ tự ưu tiên
const PREFERRED_MODELS = [
  "gemini-3.5-flash",
  "gemini-3.5-flash-lite",
  "gemini-flash-lite-latest",
  "gemini-flash-latest"
];

    // Hàm tự động phát hiện model nhẹ nhất còn khả dụng
async function getBestAvailableModel(ai) {
  try {
    const available = [];
    const response = await ai.models.list();
    for await (const m of response) {
      if (m.supportedActions?.includes("generateContent")) {
        available.push(m.name.replace("models/", ""));
      }
    }

    // Quét theo thứ tự ưu tiên
    for (const model of PREFERRED_MODELS) {
      if (available.includes(model)) return model;
    }

    // Dự phòng an toàn tuyệt đối nếu không khớp cái nào
    return "gemini-flash-lite-latest";
  } catch (e) {
    return "gemini-flash-lite-latest";
  }
}

const PREFERRED_GROQ_MODELS = [
  "openai/gpt-oss-20b",    
  "openai/gpt-oss-120b",    
  "qwen/qwen3.8-27b"
];
let cachedGroqModel = null;

async function getBestGroqModel(apiKey) {
  try {
    const res = await fetch("https://api.groq.com/openai/v1/models", {
      headers: { Authorization: `Bearer ${apiKey}` }
    });
    if (!res.ok) return "openai/gpt-oss-20b";
    
    const data = await res.json();
    const available = data.data.map(m => m.id);

    for (const model of PREFERRED_GROQ_MODELS) {
      if (available.includes(model)) return model;
    }
    return "openai/gpt-oss-20b";
  } catch (e) {
    return "openai/gpt-oss-20b";
  }
}

async function callGroq(apiKey, content) {
  if (!cachedGroqModel) {
    cachedGroqModel = await getBestGroqModel(apiKey);
    console.log(`[GROQ] Đang kích hoạt model: ${cachedGroqModel}`);
  }

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    signal: AbortSignal.timeout(12000),
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: cachedGroqModel,
      response_format: { type: "json_object" },
      messages: [
        { 
          role: "system", 
          content: `${systemInstruction}\nYou must respond in valid JSON format.` 
        },
        { 
          role: "user", 
          content: content 
        },
      ],
      temperature: 0.1,
    }),
  });

  if (!res.ok) {
    const errorText = await res.text();
    const error = new Error(`Groq API Error: ${res.status} - ${errorText}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  return data.choices[0].message.content;
}

let cachedActiveModel = null;

exports.moderateContent = onCall({ 
  region: "asia-southeast1",
  timeoutSeconds: 120,
}, async (request) => {
  const content = request.data.text;
  if (!content || typeof content !== "string") {
    throw new HttpsError("invalid-argument", "Nội dung cần kiểm duyệt không hợp lệ.");
  }

  const now = admin.firestore.Timestamp.now();
  const db = admin.firestore();

  const keysSnapshot = await db
    .collection("api_keys")
    .where("provider", "in", ["gemini", "groq"])
    .where("is_active", "==", true)
    .get();

  if (keysSnapshot.empty) {
    throw new HttpsError("failed-precondition", "Tất cả cá kiểm duyệt tạm thời bận.");
  }

  const availableDocs = keysSnapshot.docs
    .filter((doc) => {
      const cooldownUntil = doc.data().cooldown_until;
      return !cooldownUntil || cooldownUntil.toMillis() <= now.toMillis();
    })
    .sort((a, b) => {
      const aTime = a.data().last_used_at ? a.data().last_used_at.toMillis() : 0;
      const bTime = b.data().last_used_at ? b.data().last_used_at.toMillis() : 0;
      return aTime - bTime;
    });

  if (availableDocs.length === 0) {
    throw new HttpsError("resource-exhausted", "Tất cả cá kiểm duyệt đều đang ngủ nướng.");
  }

  for (let i = 0; i < availableDocs.length; i++) {
    const doc = availableDocs[i];
    const docRef = doc.ref;
    const apiKey = doc.data().api_key;
    let timeoutId = null;
    const provider = (doc.data().provider || "gemini").toLowerCase();

    try {
      const timeoutPromise = new Promise((_, reject) => {
        timeoutId = setTimeout(() => reject(new Error("AI_TIMEOUT_12S")), 12000);
      });

      let executePromise;

      if (provider === "groq") {
        executePromise = callGroq(apiKey, content);
      } else {
        const ai = new GoogleGenAI({ apiKey: apiKey });
        
        if (!cachedActiveModel) {
          cachedActiveModel = await getBestAvailableModel(ai);
          console.log(`Đã phát hiện và gán model nhẹ nhất: ${cachedActiveModel}`);
        }
        executePromise = ai.models.generateContent({
        model: cachedActiveModel,
        contents: content,
        config: {
          systemInstruction: systemInstruction,
          responseMimeType: "application/json",
          thinkingConfig: {
            thinkingBudget: 0,
          },
          responseSchema: {
            type: Type.OBJECT,
            properties: {
              isValid: { 
                type: Type.BOOLEAN, 
                description: "true nếu hợp lệ, false nếu vi phạm" 
              },
              category: {
                type: Type.STRING,
                enum: [
                  "none",
                  "chong_pha_chinh_tri",
                  "bao_luc_de_doa",
                  "tiet_lo_danh_tinh",
                  "thu_ghet_tuc_tiu",
                  "vo_nghia_spam"
                ],
                description: "Danh mục vi phạm nếu có: 'chong_pha_chinh_tri', 'bao_luc_de_doa', 'tiet_lo_danh_tinh', 'thu_ghet_tuc_tiu', 'vo_nghia_spam', hoặc 'none'"
              },
              reason: { 
                type: Type.STRING, 
                description: "Lý do ngắn gọn nếu vi phạm, nếu hợp lệ thì để chuỗi rỗng" 
              },
            },
            required: ["isValid", "category", "reason"],
          },
        },
      }).then(res => res.text);
    }

      const response = await Promise.race([executePromise, timeoutPromise]);
      clearTimeout(timeoutId);

      // Cập nhật lại mốc thời gian vừa dùng key
      await docRef.update({
        last_used_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      const cleanJson = (typeof response === "string" ? response : response.text || "")
        .replace(/```json|```/g, "")
        .trim();
        
      const result = JSON.parse(cleanJson);
      return {
        isValid: result.isValid === true,
        category: result.category || "none",
        reason: result.reason || "",
      };

    } catch (error) {
      if (timeoutId) clearTimeout(timeoutId);

      const errorMessage = error.message || "";
      const errorCode = error.status || error.code;

      console.warn(`Key ${doc.id} gặp sự cố:`, errorMessage);

      if (errorMessage.includes("TIMEOUT")) {
        continue;
      }

      if (errorMessage.includes("404") || errorMessage.includes("503") || errorCode === 404 || errorCode === 503) {
        if (provider === "groq") cachedGroqModel = null;
        else cachedActiveModel = null;
      }

      // Nếu lỗi cạn quota / hết tiền (429, 402 hoặc RESOURCE_EXHAUSTED)
      const isCooldownRelated =
        errorCode === 429 ||
        errorCode === 402 ||
        errorCode === 503 ||
        errorMessage.includes("429") ||
        errorMessage.includes("402") ||
        errorMessage.includes("503") ||
        errorMessage.includes("RESOURCE_EXHAUSTED") ||
        errorMessage.includes("UNAVAILABLE");

      if (isCooldownRelated) {
        // Đưa key này vào cooldown để các lần gọi sau tạm bỏ qua
        const cooldownTime = new Date(Date.now() + 10 * 1000);
        await docRef.update({
          cooldown_until: admin.firestore.Timestamp.fromDate(cooldownTime),
        });
        console.log(`Key ${doc.id} dính quota/overload, đã set cooldown 10s.`);
      }
      // Vòng lặp for sẽ tự động chạy sang doc tiếp theo trong danh sách
      continue;
    }
  }

  // Duyệt hết toàn bộ availableDocs mà không cái nào chạy được
  throw new HttpsError("resource-exhausted", "Tất cả các cá kiểm duyệt đều đang kiệt sức mất rồi!!!");
});

//firebase deploy --only functions:moderateContent