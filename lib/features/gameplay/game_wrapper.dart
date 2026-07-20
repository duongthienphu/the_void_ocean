import 'package:flutter/material.dart';
import 'package:ocean/features/gameplay/map_mobile.dart';
import 'package:ocean/features/gameplay/map_web.dart';
import 'package:ocean/features/gameplay/map_small_web.dart';
import 'package:flutter/foundation.dart';

class GameWrapper extends StatelessWidget {
  const GameWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 1. Kiểm tra xem ứng dụng có đang chạy trên nền tảng Web hay không
        if (kIsWeb) {
          if (constraints.maxWidth >= 1100) {
            return const OceanWebScreen();
          } else {
            // Nếu là Web nhưng kích thước màn hình nhỏ hơn 1100
            return const OceanSmallWebScreen();
          }
        }

        // 2. Nếu không phải Web (chạy trên Android/iOS/Windows native) thì trả về Mobile
        return const OceanMobileScreen();
      },
    );
  }
}