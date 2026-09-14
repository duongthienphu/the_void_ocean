import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 

import 'package:ocean/features/auth/login_mobile.dart';
import 'package:ocean/features/auth/login_web.dart';
import 'package:ocean/features/gameplay/game_wrapper.dart';
 
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
 
  void _enterOcean(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const GameWrapper()),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // 1. Nếu người dùng TRUY CẬP BẰNG WEB
    if (kIsWeb) {
      // Nếu màn hình Web bị co nhỏ lại dưới 1080px, đẩy vào màn hình Web Small (không có đăng ký)
      if (width < 1080) {
        return LoginMobileScreen(onAuthenticated: () => _enterOcean(context));
      }
      // Nếu màn hình Web to bình thường, hiển thị giao diện Web lớn chuẩn chỉ
      return LoginWebScreen(onAuthenticated: () => _enterOcean(context));
    }
    
    // 2. Nếu người dùng TRUY CẬP BẰNG APP MOBILE THẬT (Android/iOS)
    return LoginMobileScreen(onAuthenticated: () => _enterOcean(context));
  }
}