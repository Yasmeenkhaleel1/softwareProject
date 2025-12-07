import 'package:flutter/material.dart';

class CustomerNotificationsPage extends StatelessWidget {
  const CustomerNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: const Color(0xFF62C6D9),
      ),
      body: const Center(
        child: Text(
          "Notifications center will be here.\n"
          "Later بنربطها مع نظام الـ bookings/payments.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
