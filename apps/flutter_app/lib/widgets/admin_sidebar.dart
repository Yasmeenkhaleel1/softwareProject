import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AdminSidebar({super.key, this.selectedIndex = 0, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Dashboard', Icons.dashboard),
      ('Experts', Icons.supervised_user_circle),
      ('Logout', Icons.logout),
    ];

    return Container(
      width: 240,
      color: const Color(0xFF62C6D9),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            'ADMIN PANEL',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 40),
          ...List.generate(items.length, (i) {
            final (title, icon) = items[i];
            final selected = selectedIndex == i;

            return ListTile(
              leading: Icon(icon, color: selected ? Colors.black : Colors.white),
              title: Text(title,
                  style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold)),
              tileColor: selected ? Colors.white : Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onTap: () {
                if (title == "Logout") {
                  Navigator.pushReplacementNamed(context, '/login_page');
                } else {
                  onSelect(i);
                }
              },
            );
          }),
        ],
      ),
    );
  }
}
