import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';
import '../../config/api_config.dart';
import 'chat_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _conversations = [];
  String? _myUserId;

  static const Color _brand = Color(0xFF62C6D9);
  static const Color _brandDark = Color(0xFF285E6E);
  static const Color _bg = Color(0xFFF4F7FB);

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _myUserId = prefs.getString('userId');
    await _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await ApiService.fetchMyConversations();
      setState(() {
        _conversations = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _brand,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Messages",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 900;

          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE7F5F8), Color(0xFFF7FBFD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ===== Header intro (ستايل SaaS) =====
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Your inbox with experts",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _brandDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _conversations.isEmpty
                                      ? "Once you start messaging experts, all your conversations will appear here."
                                      : "Continue your 1-to-1 conversations, follow up on sessions, and keep everything in one place.",
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isWide) const SizedBox(width: 16),
                          if (isWide)
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 40,
                              color: _brandDark,
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ===== قائمة المحادثات / Empty state =====
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadConversations,
                          child: _conversations.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 80),
                                    Card(
                                      elevation: 6,
                                      shadowColor: Colors.black12,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(22),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isWide ? 28 : 20,
                                          vertical: isWide ? 22 : 18,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            Center(
                                              child: Icon(
                                                Icons.forum_outlined,
                                                size: 42,
                                                color: _brandDark,
                                              ),
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              "No conversations yet",
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              "After you book a session and start messaging an expert, "
                                              "your conversations will show up here with unread counters and last messages.",
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(
                                      top: 4, bottom: 16),
                                  itemCount: _conversations.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final conv = _conversations[index];

                                    final customer =
                                        (conv['customer'] as Map?)
                                                ?.cast<String, dynamic>() ??
                                            <String, dynamic>{};
                                    final expert =
                                        (conv['expert'] as Map?)
                                                ?.cast<String, dynamic>() ??
                                            <String, dynamic>{};

                                    final bool amCustomer =
                                        customer['_id']?.toString() ==
                                            _myUserId;

                                    final other =
                                        amCustomer ? expert : customer;

                                    final otherName =
                                        (other['name'] ?? other['email'] ?? 'User')
                                            .toString();

                                    // ✅ نصلح رابط الصورة باستخدام ApiConfig
                                    final rawAvatar =
                                        (other['profilePic'] ?? '').toString();
                                    final avatarUrl =
                                        ApiConfig.fixAssetUrl(rawAvatar);

                                    final lastPreview =
                                        (conv['lastMessagePreview'] ?? '')
                                            .toString()
                                            .trim();
                                    final lastAtStr =
                                        (conv['lastMessageAt'] ?? '')
                                            .toString();

                                    final int unread = amCustomer
                                        ? (conv['unreadForCustomer'] ?? 0) as int
                                        : (conv['unreadForExpert'] ?? 0) as int;

                                    return _buildConversationCard(
                                      context: context,
                                      conv: conv,
                                      otherName: otherName,
                                      avatarUrl: avatarUrl,
                                      lastPreview: lastPreview,
                                      lastAtStr: lastAtStr,
                                      unread: unread,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversationCard({
    required BuildContext context,
    required Map<String, dynamic> conv,
    required String otherName,
    required String avatarUrl,
    required String lastPreview,
    required String lastAtStr,
    required int unread,
  }) {
    final String dateShort =
        lastAtStr.isNotEmpty && lastAtStr.length >= 10
            ? lastAtStr.substring(0, 10)
            : '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: unread > 0
              ? _brand.withOpacity(0.7)
              : const Color(0xFFE3EBF3),
          width: unread > 0 ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                conversationId: conv['_id'].toString(),
                otherUserName: otherName,
                otherUserAvatar: avatarUrl,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _brand.withOpacity(0.18),
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        otherName.isNotEmpty
                            ? otherName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          color: _brandDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Name + last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            unread > 0 ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastPreview.isEmpty ? "Say hi 👋" : lastPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Time + unread badge
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (dateShort.isNotEmpty)
                    Text(
                      dateShort,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _brand,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unread.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
