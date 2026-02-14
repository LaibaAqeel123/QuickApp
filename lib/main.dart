import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/theme/app_theme.dart';
import 'package:food_delivery_app/presentation/auth/screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodSupply Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}