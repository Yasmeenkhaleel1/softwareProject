//widgets/customer_appbar
import 'package:flutter/material.dart';
import 'package:flutter_app/pages/profile_page.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoggedIn;
  final Function(String)? onMenuSelected;

  const CustomAppBar({
    super.key,
    required this.isLoggedIn,
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF5BB19F),
      elevation: 0,
      titleSpacing: 10,
      title: Row(
        children: [
          Image.asset('assets/images/treasure_icon.png', height: 26),
          const SizedBox(width: 6),
          const Text(
            "Lost Treasures",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => onMenuSelected?.call('home'),
          child: const Text("Home", style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () => onMenuSelected?.call('about'),
          child: const Text("About", style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () => onMenuSelected?.call('services'),
          child: const Text("Services", style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () => onMenuSelected?.call('contact'),
          child: const Text("Contact", style: TextStyle(color: Colors.white)),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle, color: Colors.black, size: 28),
          color: Colors.white,
          onSelected: (value) {
            if (onMenuSelected != null) onMenuSelected!(value);
          },
          itemBuilder: (context) {
            if (!isLoggedIn) {
              return const [
                PopupMenuItem(value: 'login', child: Text('Log In')),
                PopupMenuItem(value: 'signup', child: Text('Sign Up')),
              ];
            } else {
              return const [
                PopupMenuItem(value: 'profile', child: Text('Profile')),
                PopupMenuItem(value: 'logout', child: Text('Log Out')),
              ];
            }
          },
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}