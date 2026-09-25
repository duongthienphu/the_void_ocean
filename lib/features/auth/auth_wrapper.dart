import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ocean/features/auth/login_mobile.dart';
import 'package:ocean/features/auth/login_web.dart';
import 'package:ocean/features/gameplay/game_wrapper.dart';
 
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Trong lúc app đang đọc token/phiên từ bộ nhớ máy
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF06131A),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2DD4BF),
              ),
            ),
          );
        }
        final user = snapshot.data;
        if (user != null) {
          return const GameWrapper();
        }
        final width = MediaQuery.of(context).size.width;
        if (kIsWeb) {
          if (width < 1080) {
            return LoginMobileScreen(onAuthenticated: () {});
          }
          return LoginWebScreen(onAuthenticated: () {});
        }

        return LoginMobileScreen(onAuthenticated: () {});
      },
    );
  }
}