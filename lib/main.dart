import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/theme/app_theme.dart';
import 'package:food_delivery_app/presentation/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background notification: ${message.notification?.title}');
}

Future<void> _initNotifications() async {
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
  InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final plugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (plugin != null) {
    await plugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.high,
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized!');
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initNotifications();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground: ${message.notification?.title}');
      final notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('FCM Token: $token');
  } catch (e) {
    debugPrint('Firebase error: $e');
  }

  try {
    Stripe.publishableKey =
    'pk_test_51TChtMFRpcmxK2pQ84PzPDoZ0mVsQWP7OvJF45rpu6FFM96rf4vekt69ZdXmZTE3DDL2rQ2i5jCIWUlfSnQJusOD00XSG3Xwxm';
    await Stripe.instance.applySettings();
    debugPrint('Stripe initialized!');
  } catch (e) {
    debugPrint('Stripe error: $e');
  }

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
      home: const SplashScreen(),
    );
  }
}