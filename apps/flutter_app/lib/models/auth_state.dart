import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_service.dart';

class AuthState extends ChangeNotifier {
  String? _token;
  String? _userRole; // Can be 'customer', 'specialist', or 'admin'
  bool _isLoading = true;

  String? get token => _token;
  String? get userRole => _userRole;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  AuthState() {
    _loadUser();
  }

  // Loads the saved token and role from local storage on app startup
  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userRole = prefs.getString('userRole'); 
    _isLoading = false;
    notifyListeners();
  }

  // Called after successful login API response
  void login(String token, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('userRole', role);
    _token = token;
    _userRole = role;
    notifyListeners();
  }

  // Called for logout
  void logout() async {
    await ApiService.logout(); // Removes token from SharedPreferences
    _token = null;
    _userRole = null;
    notifyListeners();
  }
}