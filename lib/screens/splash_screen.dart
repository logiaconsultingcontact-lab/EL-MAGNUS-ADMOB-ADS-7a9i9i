import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ELMAGNUS/screens/app_initializer_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // الانتقال للشاشة التالية بعد 4 ثوانٍ
    Timer(const Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AppInitializerScreen(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF010021), // الخلفية الاحتياطية
        child: Center(
          child: Image.asset(
            "assets/images/splash_bg.gif",
            // هنا نترك fit افتراضي (null) لتظهر بالحجم الطبيعي في الوسط
          ),
        ),
      ),
    );
  }
}