import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Hàm xóa dấu tiếng Việt để tạo email không bị lỗi hệ thống
  String _clearDiacritics(String str) {
    const withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    for (int i = 0; i < withDiacritics.length; i++) {
      str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return str.trim().replaceAll(' ', '').toLowerCase();
  }

  /// Hàm xử lý đăng ký tài khoản ẩn danh qua Biệt danh
  Future<UserCredential?> registerWithNickname({
    required String nickname,
    required String password,
  }) async {
    try {
      if (nickname.trim().isEmpty || password.isEmpty) {
        throw Exception('Biệt danh và mật khẩu không được để trống.');
      }

      // 1. Sinh Email ảo từ biệt danh sạch dấu
      String cleanName = _clearDiacritics(nickname);
      String customEmail = '$cleanName@voidocean.com';

      // 2. Tạo tài khoản trên Firebase Authentication[cite: 3]
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: customEmail,
        password: password,
      );

      // 3. Tạo Document lưu thông tin hiển thị sang Firestore bằng UID vừa sinh ra[cite: 2, 3]
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': customEmail,
          'nickname': nickname.trim(), // Giữ nguyên biệt danh gốc có dấu để hiển thị trong game
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Biệt danh này đã được cư dân khác sử dụng.');
      } else if (e.code == 'weak-password') {
        throw Exception('Mật khẩu quá yếu, cần tối thiểu 6 ký tự.');
      }
      throw Exception(e.message ?? 'Đã xảy ra lỗi xác thực.');
    } catch (e) {
      throw Exception('Không thể kết nối đến máy chủ: $e');
    }
  }
}