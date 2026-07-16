import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ocean/features/auth/auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print("Firebase đã được khởi tạo trước đó: $e");
  }
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const VoidOceanApp());
}

class VoidOceanApp extends StatelessWidget {
  const VoidOceanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dai duong an danh',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF06131A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2DD4BF),
          secondary: Color(0xFFFF8A7A),
          surface: Color(0xFF0B1C24),
        ),
        textTheme: baseTheme.textTheme.apply(
          bodyColor: const Color(0xFFEAF6F4),
          displayColor: const Color(0xFFEAF6F4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF06131A).withValues(alpha: 0.66),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF5EEAD4)),
          ),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
