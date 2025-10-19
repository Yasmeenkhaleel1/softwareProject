import 'package:flutter/material.dart';

class ExpertSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const ExpertSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
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
        color: Colors.white,
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
            leading: Icon(items[i].icon,
                color: active ? const Color(0xFF62C6D9) : Colors.grey[700]),
            title: Text(
              items[i].label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? const Color(0xFF0F172A) : Colors.grey[800],
            )),
            selected: active,
            selectedTileColor: const Color(0x1A62C6D9),
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
