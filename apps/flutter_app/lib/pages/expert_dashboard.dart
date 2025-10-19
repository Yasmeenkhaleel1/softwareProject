import 'package:flutter/material.dart';
import '../widgets/expert_sidebar.dart';
import '../widgets/stat_card.dart';

class ExpertDashboardPage extends StatefulWidget {
  const ExpertDashboardPage({super.key});

  @override
  State<ExpertDashboardPage> createState() => _ExpertDashboardPageState();
}

class _ExpertDashboardPageState extends State<ExpertDashboardPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;

    final appBar = AppBar(
      backgroundColor: const Color(0xFF62C6D9),
      title: const Text(
        'Expert Dashboard',
        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );

    final sidebar = ExpertSidebar(
      selectedIndex: _selected,
      onSelected: (i) {
        setState(() => _selected = i);
        if (i == 5) {
          // Logout action placeholder
          Navigator.popUntil(context, ModalRoute.withName('/'));
        }
        // TODO: لاحقًا بدّل الـ body حسب العنصر المختار
      },
    );

    return Scaffold(
      appBar: isWide ? null : appBar,
      drawer: isWide ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (isWide) sidebar,
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (isWide)
                  SliverAppBar(
                    backgroundColor: const Color(0xFF62C6D9),
                    pinned: true,
                    toolbarHeight: 64,
                    title: const Text(
                      'Expert Dashboard',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== Header (Profile + rating) =====
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.04),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(
                                color: const Color(0xFFE5E7EB), width: 1),
                          ),
                          child: Row(
                            children: [
                              // صورة البروفايل
                              const CircleAvatar(
                                radius: 36,
                                backgroundImage:
                                    AssetImage('assets/images/experts.png'),
                              ),
                              const SizedBox(width: 16),
                              // الاسم + تخصص + تقييم
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Eng. Kareem A.',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'IoT & Embedded Systems Expert',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        ...List.generate(
                                          4,
                                          (_) => const Icon(Icons.star,
                                              color: Color(0xFFFFC857),
                                              size: 20),
                                        ),
                                        const Icon(Icons.star_half,
                                            color: Color(0xFFFFC857), size: 20),
                                        const SizedBox(width: 8),
                                        Text('4.5 (126 reviews)',
                                            style: TextStyle(
                                                color: Colors.grey[700])),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // زر تعديل الملف
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF62C6D9),
                                ),
                                onPressed: () {},
                                child: const Text('Edit Profile'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ===== Stats Grid =====
                        LayoutBuilder(
                          builder: (context, c) {
                            final w = c.maxWidth;
                            final cross = w > 1100
                                ? 4
                                : w > 800
                                    ? 3
                                    : w > 600
                                        ? 2
                                        : 1;
                            return GridView.count(
                              crossAxisCount: cross,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: const [
                                StatCard(
                                  title: 'Services',
                                  value: '12',
                                  icon: Icons.home_repair_service,
                                ),
                                StatCard(
                                  title: 'Clients',
                                  value: '48',
                                  icon: Icons.group,
                                ),
                                StatCard(
                                  title: 'Bookings',
                                  value: '19',
                                  icon: Icons.event_available,
                                ),
                                StatCard(
                                  title: 'Wallet',
                                  value: '\$1,260',
                                  icon: Icons.account_balance_wallet,
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // ===== محتوى مبدئي حسب العنصر المختار من الـ Sidebar =====
                        _SelectedSection(index: _selected),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSection extends StatelessWidget {
  final int index;
  const _SelectedSection({required this.index});

  @override
  Widget build(BuildContext context) {
    final titles = [
      'My Profile',
      'My Services',
      'My Bookings',
      'Messages',
      'Wallet',
      'Logout',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        'Section: ${titles[index]} (placeholder)',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}
