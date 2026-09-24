const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { GoogleGenAI, Type } = require("@google/genai");

admin.initializeApp();  
  exports.moderateContent = onCall({ region: "asia-southeast1" }, async (request) => {
  const content = request.data.text;
  if (!content || typeof content !== "string") {
    throw new HttpsError("invalid-argument", "Nội dung cần kiểm duyệt không hợp lệ.");
  }

  const now = admin.firestore.Timestamp.now();
  const db = admin.firestore();

  // 1. Lấy tất cả key đang hoạt động và không trong thời gian cooldown
  const keysSnapshot = await db
    .collection("api_keys")
    .where("provider", "==", "gemini")
    .where("is_active", "==", true)
    .get();

  if (keysSnapshot.empty) {
    throw new HttpsError("failed-precondition", "Tất cả cá kiểm duyệt tạm thời bận.");
  }

  // Lọc các key hợp lệ và sắp xếp theo lượt dùng lâu nhất
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
    for (let i = 0; i < availableDocs.length; i++) {
    const doc = availableDocs[i];
    const docRef = doc.ref;
    const apiKey = doc.data().api_key;

    try {
      const ai = new GoogleGenAI({ apiKey: apiKey });
      const response = await ai.models.generateContent({
        model: "gemini-3.5-flash",
        contents: content,
        config: {
          systemInstruction: systemInstruction,
          responseMimeType: "application/json",
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
      });

      // Cập nhật lại mốc thời gian vừa dùng key
      await docRef.update({
        last_used_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      const result = JSON.parse(response.text.trim());
      return {
        isValid: result.isValid === true,
        category: result.category || "none",
        reason: result.reason || "",
      };

    } catch (error) {
      console.warn(`Key ${doc.id} gặp sự cố:`, error.message || error);

      // Nếu lỗi cạn quota / hết tiền (429, 402 hoặc RESOURCE_EXHAUSTED)
      const isQuotaError = 
        error.status === 429 || 
        error.status === 402 || 
        (error.message && (error.message.includes("429") || error.message.includes("RESOURCE_EXHAUSTED") || error.message.includes("402")));

      if (isQuotaError) {
        // Đưa key này vào hàng chờ cooldown (ví dụ: 15 phút)
        const cooldownTime = new Date(Date.now() + 15 * 60 * 1000);
        await docRef.update({
          cooldown_until: admin.firestore.Timestamp.fromDate(cooldownTime),
        });

        console.log(`Key ${doc.id} đã bị đưa vào cooldown. Tự động chuyển sang key tiếp theo...`);
        // Vòng lặp for sẽ tự động chạy sang doc tiếp theo trong danh sách
        continue;
      }

      // Nếu là lỗi cú pháp hay lỗi khác không phải quota, ném ra ngoài
      throw new HttpsError("internal", "Lỗi xử lý kiểm duyệt nội dung.");
    }
  }

  // Nếu duyệt qua toàn bộ danh sách key mà cái nào cũng hết hạn mức
  throw new HttpsError("resource-exhausted", "Tất cả các cá kiểm duyệt đều đang kiệt sức mất rồi!!!");
});