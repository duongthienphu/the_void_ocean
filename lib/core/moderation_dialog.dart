import 'package:flutter/material.dart';

Future<void> showModerationAlert({
  required BuildContext context,
  required String category,
  required String reason,
}) {
  String title;
  IconData icon;
  Color accentColor;

  switch (category) {
    case 'chong_pha_chinh_tri':
      title = 'Nội dung chính trị nhạy cảm';
      icon = Icons.policy_outlined;
      accentColor = const Color(0xFFF87171);
      break;
    case 'bao_luc_de_doa':
      title = 'Bạo lực hoặc đe dọa';
      icon = Icons.warning_amber_rounded;
      accentColor = const Color(0xFFEF4444);
      break;
    case 'tiet_lo_danh_tinh':
      title = 'Tiết lộ danh tính cá nhân';
      icon = Icons.lock_outline_rounded;
      accentColor = const Color(0xFFFBBF24);
      break;
    case 'thu_ghet_tuc_tiu':
      title = 'Ngôn từ thù ghét, thô tục';
      icon = Icons.sentiment_very_dissatisfied_rounded;
      accentColor = const Color(0xFFF43F5E);
      break;
    case 'vo_nghia_spam':
      title = 'Nội dung vô nghĩa / Spam';
      icon = Icons.delete_sweep_outlined;
      accentColor = const Color(0xFF94A3B8);
      break;
    default:
      title = 'Chưa thể gửi tâm sự';
      icon = Icons.info_outline_rounded;
      accentColor = const Color(0xFF38BDF8);
  }

  return showDialog<void>(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accentColor.withOpacity(0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              reason.isNotEmpty
                  ? reason
                  : 'Nội dung chưa phù hợp với quy tắc của The Void Ocean. Vui lòng chia sẻ tâm sự chân thực khác.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withOpacity(0.2),
                  foregroundColor: accentColor,
                  elevation: 0,
                  side: BorderSide(color: accentColor.withOpacity(0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text(
                  'Tôi đã hiểu',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}