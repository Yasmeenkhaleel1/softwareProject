// lib/widgets/expert_sidebar.dart
import 'package:flutter/material.dart';
import '../pages/my_availability_page.dart'; // ✅ استيراد صفحة التوافر

class ExpertSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color background;

  const ExpertSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.background = const Color(0xFF62C6D9),
  });

  @override
  Widget build(BuildContext context) {
    // ✅ أضفنا العنصر الجديد My Availability
    final items = <_SideItem>[
      _SideItem(icon: Icons.person, label: 'My Profile'),
      _SideItem(icon: Icons.home_repair_service, label: 'My Services'),
      _SideItem(icon: Icons.event_available, label: 'My Bookings'),
      _SideItem(icon: Icons.access_time, label: 'My Availability'), // ✅ الجديد هنا
      _SideItem(icon: Icons.chat_bubble, label: 'Messages'),
      _SideItem(icon: Icons.bar_chart, label: 'My Earnings'),
      _SideItem(icon: Icons.logout, label: 'Logout'),
    ];

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: background,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
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
            selectedTileColor: Colors.white.withOpacity(.18),
           onTap: () {
  final label = items[i].label;

  if (label == 'My Availability') {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyAvailabilityPage()),
    ).then((_) => onSelected(3));
  }

  else if (label == 'My Earnings') {
    Navigator.pushNamed(context, '/expert_earnings')
        .then((_) => onSelected(i));
  }

  else {
    onSelected(i);
  }
},

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
