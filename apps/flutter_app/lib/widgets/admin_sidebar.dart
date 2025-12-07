import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AdminSidebar({
    super.key,
    this.selectedIndex = 0,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Dashboard', Icons.dashboard),
      ('Experts', Icons.supervised_user_circle),
      ('Payments', Icons.account_balance_wallet_outlined),
      ('Earnings & Refunds', Icons.pie_chart), 
      ('Logout', Icons.logout),
    ];

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF62C6D9),
            Color(0xFF347C8B),
            Color(0xFF244C63),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            'ADMIN PANEL',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 40),
          ...List.generate(items.length, (i) {
            final (title, icon) = items[i];
            final selected = selectedIndex == i;

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(
                  icon,
                  color: selected ? Colors.black : Colors.white,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                tileColor:
                    selected ? Colors.white : Colors.white.withOpacity(0.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onTap: () {
                  if (title == "Logout") {
                    Navigator.pushReplacementNamed(context, '/login_page');
                  } else {
                    onSelect(i);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
