import 'package:flutter/material.dart';

class ExpertSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color background; // ✅ أضفنا المتغير

  const ExpertSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.background = const Color(0xFF62C6D9), // ✅ قيمة افتراضية
  });

  @override
  Widget build(BuildContext context) {
    final items = <_SideItem>[
      _SideItem(icon: Icons.person, label: 'My Profile'),
      _SideItem(icon: Icons.home_repair_service, label: 'My Services'),
      _SideItem(icon: Icons.event_available, label: 'My Bookings'),
      _SideItem(icon: Icons.chat_bubble, label: 'Messages'),
      _SideItem(icon: Icons.account_balance_wallet, label: 'Wallet'),
      _SideItem(icon: Icons.logout, label: 'Logout'),
    ];

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: background, // ✅ استخدم لون الخلفية
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 24),
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final active = selectedIndex == i;
          return ListTile(
            leading: Icon(
              items[i].icon,
              color: active ? Colors.white : Colors.white.withOpacity(.7),
            ),
            title: Text(
              items[i].label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : Colors.white.withOpacity(.9),
              ),
            ),
            selected: active,
            selectedTileColor: Colors.white.withOpacity(.18), // ✅ لمسة احترافية
            onTap: () => onSelected(i),
          );
        },
      ),
    );
  }
}

class _SideItem {
  final IconData icon;
  final String label;
  _SideItem({required this.icon, required this.label});
}
