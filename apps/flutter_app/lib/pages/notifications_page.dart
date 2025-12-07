import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const baseUrl = "http://localhost:5000/api/notifications";
  List<dynamic> notifs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final res = await http.get(
      Uri.parse(baseUrl),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        notifs = data['notifications'] ?? [];
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Color(0xFF62C6D9),
      ),
      body: loading 
          ? const Center(child: CircularProgressIndicator())
          : notifs.isEmpty
              ? const Center(child: Text("No notifications yet"))
              : ListView.builder(
                  itemCount: notifs.length,
                  itemBuilder: (_, i) {
                    final n = notifs[i];
                    return ListTile(
                      leading: const Icon(Icons.notifications),
                      title: Text(n['title']),
                      subtitle: Text(n['message']),
                      onTap: () {},
                    );
                  },
                ),
    );
  }
}
