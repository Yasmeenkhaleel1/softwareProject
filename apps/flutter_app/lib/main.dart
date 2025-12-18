// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// config + providers
import 'config/api_config.dart';
import 'providers/bookings_provider.dart';

// pages
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/change_password_page.dart';
import 'pages/verify_code_page.dart';
import 'pages/expert_profile_page.dart';
import 'pages/expert_dashboard_page.dart';
import 'pages/waiting_approval_page.dart';
import 'pages/customer_dashboard_page.dart';
import 'pages/customer_profile_page.dart';
import 'pages/ExpertDetailPage.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/expert_earnings_page.dart';

import 'services/auth_service.dart';
import 'services/push_notifications.dart';


// ----------------------------------------------------------------------------
//🔥 FCM Background Handler + Local Notifications
// ----------------------------------------------------------------------------
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint("📩 BG Notification: ${message.notification?.title}");
}



// ----------------------------------------------------------------------------
// MAIN
// ----------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1) Stripe فقط للموبايل / الديسكتوب (ليس للويب)
  if (!kIsWeb) {
    Stripe.publishableKey = ApiConfig.stripePublishableKey;
    Stripe.merchantIdentifier = 'lost.treasures.app';
    await Stripe.instance.applySettings();
  }

  // ✅ 2) Firebase (مش مشكلة يشتغل على الويب كمان)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

if (!kIsWeb) {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}



  // ✅ 4) تشغيل التطبيق
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookingsProvider()),
      ],
      child: const LostTreasuresApp(),
    ),
  );
}

class LostTreasuresApp extends StatefulWidget {
  const LostTreasuresApp({super.key});

  @override
  State<LostTreasuresApp> createState() => _LostTreasuresAppState();
}

class _LostTreasuresAppState extends State<LostTreasuresApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _role;
  bool _isApproved = true;
  bool _hasProfile = true;
bool _pushInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

Future<void> _ensurePushInitialized() async {
  if (_pushInitialized) return;

  // لازم يكون المستخدم عامل Login (JWT محفوظ)
  final prefs = await SharedPreferences.getInstance();
  final jwt = prefs.getString('token');
  if (jwt == null) return;

  try {
    
    await PushNotifications.init(); // ✅ هنا التسجيل بالباك + listeners
    if (!mounted) return;
      setState(() => _pushInitialized = true);

    debugPrint("✅ PushNotifications initialized");
  } catch (e) {
    debugPrint("❌ Push init failed: $e");
  }
}





  // ✅ التحقق من حالة تسجيل الدخول + الموافقة + البروفايل
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    if (token != null && role != null) {
      bool approved = true;
      bool hasProfile = true;

      if (role == 'EXPERT') {
        try {
          final res = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/me'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            approved = data['user']['isApproved'] == true;
            hasProfile = data['user']['hasProfile'] == true;
          } else {
            approved = false;
            hasProfile = false;
          }
        } catch (e) {
          approved = false;
          hasProfile = false;
        }
      }

      setState(() {
        _isLoggedIn = true;
        _role = role;
        _isApproved = approved;
        _hasProfile = hasProfile;
        _isLoading = false;
      });
     
    await _ensurePushInitialized(); 

    } else {
      setState(() {
        _isLoggedIn = false;
        _role = null;
        _isApproved = true;
        _hasProfile = true;
        _isLoading = false;
      });
    }
  }

  // ✅ تسجيل الخروج
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    


    setState(() {
       _pushInitialized = false;
      _isLoggedIn = false;
      _role = null;
      _isApproved = true;
      _hasProfile = true;
    });
  }

  // ✅ تحديد الصفحة الرئيسية بناءً على الدور
  Widget _getHomePage() {
    if (!_isLoggedIn) {
      return LandingPage(
        isLoggedIn: false,
        onLogout: _logout,
      );
    }

    switch (_role) {
      case 'EXPERT':
        if (!_hasProfile) {
          return const ExpertProfilePage();
        } else if (!_isApproved) {
          return const WaitingApprovalPage();
        } else {
          return LandingPage(
            isLoggedIn: true,
            onLogout: _logout,
            userRole: _role,
          );
        }
      case 'CUSTOMER':
        return LandingPage(
          isLoggedIn: true,
          onLogout: _logout,
          userRole: _role,
        );
      case 'ADMIN':
        return const AdminDashboardPage();
      default:
        return LandingPage(
          isLoggedIn: _isLoggedIn,
          onLogout: _logout,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lost Treasures',
      theme: ThemeData(
        primaryColor: const Color(0xFF62C6D9),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF62C6D9),
          secondary: const Color(0xFF62C6D9),
        ),
      ),
      home: _getHomePage(),
      routes: {
        '/login_page': (context) => LoginPage(
              onLoginSuccess: () async {
                await _checkLoginStatus();
                await _ensurePushInitialized();
               
              },
            ),
        '/signup_page': (context) => const SignupPage(),
        '/landing_page': (context) => LandingPage(
              isLoggedIn: _isLoggedIn,
              onLogout: _logout,
              userRole: _role,
            ),
        '/change-password': (context) => const ChangePasswordPage(),
        '/expert_profile': (context) => const ExpertProfilePage(),
        '/waiting_approval': (_) => const WaitingApprovalPage(),
        '/expert_dashboard_page': (context) => const ExpertDashboardPage(),
        '/verify-code': (context) => const VerifyCodePage(email: ''),
        '/customer_dashboard_page': (context) => const CustomerHomePage(),
        '/customer_profile_page': (context) => const CustomerProfilePage(),
        '/admin_dashboard_page': (context) => const AdminDashboardPage(),
        '/expert_details': (context) => ExpertDetailPage(expert: const {}),
        '/expert_earnings': (context) => const ExpertEarningsPage(),
      },
    );
  }
}
