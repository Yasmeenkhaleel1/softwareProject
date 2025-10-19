import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/expert_profile_page.dart';
import '../pages/profile_page.dart';
import '../pages/admin_home.dart';
class RoleRouter extends StatefulWidget {
const RoleRouter({super.key});
@override
State<RoleRouter> createState() => _RoleRouterState();
}
class _RoleRouterState extends State<RoleRouter> {
String? role;
@override
void initState() {
super.initState();
_load();
}
Future<void> _load() async {
final prefs = await SharedPreferences.getInstance();
setState(() { role = prefs.getString('role'); });
}
@override
Widget build(BuildContext context) {
if (role == null) {
return const Scaffold(body: Center(child: CircularProgressIndicator()));
}
switch (role) {
case 'EXPERT':
return const ExpertProfilePage();
case 'ADMIN':
return const AdminHome();
default:
return const ProfilePage();
}
}
}
