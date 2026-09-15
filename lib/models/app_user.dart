import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppUser {
  final String uid;
  final String email;
  final int maxStorageBytes;
  final int availableStorageBytes;
  final int postsCount;
  final String tier;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.maxStorageBytes,
    required this.availableStorageBytes,
    required this.postsCount,
    required this.tier,
    required this.createdAt,
    required this.updatedAt
  });

 factory AppUser.fromFirestore(Map<String, dynamic> data, String id) {
    return AppUser(
      uid: id,
      email: data['email'] ?? '',
      maxStorageBytes: (data['maxStorageBytes'] as num?)?.toInt() ?? 20971520,
      availableStorageBytes: (data['availableStorageBytes'] as num?)?.toInt() ?? 20971520,
      postsCount: (data['postsCount'] as num?)?.toInt() ?? 0,
      tier: data['tier'] ?? 'free',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  double get usagePercent {
    if (maxStorageBytes <= 0) return 0.0;
    final used = maxStorageBytes - availableStorageBytes;
    return (used / maxStorageBytes).clamp(0.0, 1.0);
  }

  UserTier get userTier {
    switch (tier.toLowerCase().trim()) {
      case 'bronze':
        return UserTier.bronze;
      case 'silver':
        return UserTier.silver;
      case 'gold':
        return UserTier.gold;
      case 'exclusive':
        return UserTier.exclusive;
      default:
        return UserTier.free;
    }
  }
}

enum UserTier {
  free,
  bronze,
  silver,
  gold,
  exclusive;

  String get displayName {
    switch (this) {
      case UserTier.free:
        return 'Free Tier';
      case UserTier.bronze:
        return 'Bronze Tier';
      case UserTier.silver:
        return 'Silver Tier';
      case UserTier.gold:
        return 'Golden Tier';
      case UserTier.exclusive:
        return 'Exclusive Tier';
    }
  }
}
extension UserTierStyling on UserTier {
  // Màu đơn sắc cho viền hoặc icon
  Color get primaryColor {
    switch (this) {
      case UserTier.free:
        return const Color(0xFF64748B); // Slate tối giản
      case UserTier.bronze:
        return const Color(0xFFCD7F32); // Đồng cổ
      case UserTier.silver:
        return const Color(0xFFE2E8F0); // Bạc sáng
      case UserTier.gold:
        return const Color(0xFFFFD700); // Vàng kim rực rỡ
      case UserTier.exclusive:
        return const Color(0xFF5EEAD4); // Điểm nhấn ngọc biển
    }
  }

  // Dải dải gradient mô phỏng chất liệu kim loại & Hologram 7 màu
  List<Color> get gradientColors {
    switch (this) {
      case UserTier.free:
        return [const Color(0xFF64748B), const Color(0xFF94A3B8)];
      case UserTier.bronze:
        // Ánh đồng đậm nhạt phản quang
        return [
          const Color(0xFF804A00),
          const Color(0xFFCD7F32),
          const Color(0xFFFFA040),
          const Color(0xFFCD7F32),
        ];
      case UserTier.silver:
        // Ánh bạc chrome kim loại
        return [
          const Color(0xFF94A3B8),
          const Color(0xFFF8FAFC),
          const Color(0xFFCBD5E1),
          const Color(0xFFFFFFFF),
        ];
      case UserTier.gold:
        // Ánh vàng kim hoàng gia
        return [
          const Color(0xFFB45309),
          const Color(0xFFFBBF24),
          const Color(0xFFFFFBEB),
          const Color(0xFFF59E0B),
        ];
      case UserTier.exclusive:
        // Hologram lăng kính 7 màu cực quang
        return [
          const Color(0xFFFF007F), // Hồng neon
          const Color(0xFF7928CA), // Tím thẫm
          const Color(0xFF0070F3), // Xanh sapphire
          const Color(0xFF00DFD8), // Lục lam
          const Color(0xFF79FCEE), // Trắng ngọc
          const Color(0xFFFFD600), // Vàng nắng
          const Color(0xFFFF007F), // Lặp lại khép vòng
        ];
    }
  }
}