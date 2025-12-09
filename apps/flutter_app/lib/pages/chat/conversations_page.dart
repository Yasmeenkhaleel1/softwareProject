import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';
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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: _brand,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Messages",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: _conversations.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                "No conversations yet.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _conversations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final conv = _conversations[index];

                            final customer =
                                (conv['customer'] as Map?)?.cast<String, dynamic>() ??
                                    <String, dynamic>{};
                            final expert =
                                (conv['expert'] as Map?)?.cast<String, dynamic>() ??
                                    <String, dynamic>{};

                            final bool amCustomer =
                                customer['_id']?.toString() == _myUserId;

                            final other = amCustomer ? expert : customer;

                            final otherName =
                                (other['name'] ?? other['email'] ?? 'User')
                                    .toString();
                            final avatarUrl =
                                (other['profilePic'] ?? '').toString();

                            final lastPreview =
                                (conv['lastMessagePreview'] ?? '')
                                    .toString()
                                    .trim();
                            final lastAtStr =
                                (conv['lastMessageAt'] ?? '').toString();

                            final int unread = amCustomer
                                ? (conv['unreadForCustomer'] ?? 0) as int
                                : (conv['unreadForExpert'] ?? 0) as int;

                            return Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        conversationId:
                                            conv['_id'].toString(),
                                        otherUserName: otherName,
                                        otherUserAvatar: avatarUrl,
                                      ),
                                    ),
                                  );
                                },
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      _brand.withOpacity(0.2),
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl.isEmpty
                                      ? Text(
                                          otherName.isNotEmpty
                                              ? otherName[0].toUpperCase()
                                              : "?",
                                          style: const TextStyle(
                                              color: _brandDark,
                                              fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  otherName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Text(
                                  lastPreview.isEmpty
                                      ? "Say hi 👋"
                                      : lastPreview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    if (lastAtStr.isNotEmpty)
                                      Text(
                                        lastAtStr.substring(0, 10),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    if (unread > 0)
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _brand,
                                          borderRadius:
                                              BorderRadius.circular(999),
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
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
