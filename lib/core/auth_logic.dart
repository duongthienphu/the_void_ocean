import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// 1. XỬ LÝ ĐĂNG NHẬP BẰNG GMAIL THỰC
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (email.trim().isEmpty || password.isEmpty) {
        throw Exception('Email và mật khẩu không được để trống.');
      }

      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await user.reload(); // Cập nhật trạng thái xác thực mới nhất từ server
        if (!user.emailVerified) {
          await _auth.signOut();
          throw Exception('EMAIL_NOT_VERIFIED');
        }
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Email hoặc mật khẩu không chính xác.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Định dạng địa chỉ email không hợp lệ.');
      }
      throw Exception(e.message ?? 'Đã xảy ra lỗi đăng nhập.');
    } catch (e) {
      rethrow;
    }
  }

  /// 2. XỬ LÝ ĐĂNG KÝ BẰNG GMAIL & GỬI LINK KÍCH HOẠT
  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (email.trim().isEmpty || password.isEmpty) {
        throw Exception('Email và mật khẩu không được để trống.');
      }

      // Tạo tài khoản Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Gửi link xác thực tới hộp thư đến
        await user.sendEmailVerification();

        // Tạo Document người dùng trên Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email.trim(),
          'tier' : 'free',
          'postsCount': 0,
          'maxStorageBytes': 20971520,
          'availableStorageBytes': 20971520,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Đăng xuất ngay, yêu cầu xác thực trước khi vào ứng dụng
        await _auth.signOut();
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Địa chỉ email này đã được đăng ký tài khoản.');
      } else if (e.code == 'weak-password') {
        throw Exception('Mật khẩu quá yếu, cần tối thiểu 6 ký tự.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Định dạng địa chỉ email không hợp lệ.');
      }
      throw Exception(e.message ?? 'Đã xảy ra lỗi đăng ký.');
    } catch (e) {
      rethrow;
    }
  }

  /// 3. GỬI LINK QUÊN MẬT KHẨU
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      if (email.trim().isEmpty) {
        throw Exception('Vui lòng nhập địa chỉ email để lấy lại mật khẩu.');
      }
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Không tìm thấy tài khoản tương ứng với email này.');
      }
      throw Exception(e.message ?? 'Không thể gửi email đặt lại mật khẩu.');
    }
  }

  /// 4. GỬI LẠI EMAIL KÍCH HOẠT
  Future<void> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.sendEmailVerification();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Không thể gửi lại email xác thực: $e');
    }
  }
}