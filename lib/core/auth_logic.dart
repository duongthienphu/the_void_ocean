import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Hàm lấy Device ID đa nền tảng (Windows, Android, iOS)
  Future<String> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isWindows) {
        final WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.deviceId;
      } else if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      }
    } catch (e) {
      print('Lỗi không lấy được Device ID: $e');
    }
    return 'unknown_device';
  }

  /// Hàm xóa dấu tiếng Việt để tạo email không bị lỗi hệ thống
  String _clearDiacritics(String str) {
    const withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    for (int i = 0; i < withDiacritics.length; i++) {
      str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return str.trim().replaceAll(' ', '').toLowerCase();
  }

  /// Hàm xử lý đăng nhập bằng Biệt danh
  Future<UserCredential?> signInWithNickname({
    required String nickname,
    required String password,
  }) async {
    try {
      if (nickname.trim().isEmpty || password.isEmpty) {
        throw Exception('Biệt danh và mật khẩu không được để trống.');
      }

      // 1. Sinh lại Email ảo từ biệt danh để gửi lên Firebase Auth
      String cleanName = _clearDiacritics(nickname);
      String customEmail = '$cleanName@voidocean.com';

      // 2. Gọi Firebase Auth để xác thực đăng nhập
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: customEmail,
        password: password,
      );
        return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Biệt danh hoặc mật khẩu không chính xác.');
      }
      throw Exception(e.message ?? 'Đã xảy ra lỗi đăng nhập.');
    } catch (e) {
      throw Exception('Không thể kết nối đến máy chủ: $e');
    }
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

      // 2. Lấy Device ID thực tế của thiết bị đang chạy ngầm
      String deviceId = await _getDeviceId();
      if (deviceId == 'unknown_device' || deviceId.trim().isEmpty) {
        throw Exception('Không thể định danh thiết bị. Không được phép tạo tài khoản.');
      }

      // 3. Tạo tài khoản trên Firebase Authentication
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
          'deviceId': deviceId,
          'postsCount': 0,
          'maxStorageBytes': 20971520,
          'availableStorageBytes': 20971520,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
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