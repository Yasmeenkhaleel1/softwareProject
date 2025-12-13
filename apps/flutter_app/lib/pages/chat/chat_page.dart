import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_service.dart';
import '../../config/api_config.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const Color _brand = Color(0xFF62C6D9);
  static const Color _brandDark = Color(0xFF285E6E);

  bool _loading = true;
  String? _error;
  String? _myUserId;
  List<Map<String, dynamic>> _messages = [];

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _myUserId = prefs.getString('userId');
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await ApiService.fetchConversationMessages(
        widget.conversationId,
        limit: 200,
      );
      setState(() {
        _messages = list;
        _loading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendTextMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final msg = await ApiService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );

      setState(() {
        _messages.add(Map<String, dynamic>.from(msg));
        _textCtrl.clear();
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  Future<void> _pickAndSendAttachment() async {
    if (_sending) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'doc',
          'docx',
        ],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      setState(() {
        _sending = true;
      });

      final uploaded = await ApiService.uploadChatAttachment(file);
      // {url, originalName, mimeType, ...}

      final attachmentUrl = (uploaded['url'] ?? '').toString();
      final attachmentName =
          (uploaded['originalName'] ?? file.name).toString();
      final mimeType = (uploaded['mimeType'] ?? '').toString();

      final msg = await ApiService.sendMessage(
        conversationId: widget.conversationId,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        attachmentType: mimeType,
      );

      setState(() {
        _messages.add(Map<String, dynamic>.from(msg));
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send attachment: $e')),
      );
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ نصلح رابط صورة الطرف الآخر (لو فيه)
    final fixedAvatar =
        ApiConfig.fixAssetUrl(widget.otherUserAvatar ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1F5),
      appBar: AppBar(
        backgroundColor: _brand,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: fixedAvatar.isNotEmpty
                  ? NetworkImage(fixedAvatar)
                  : null,
              child: fixedAvatar.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Secure one-to-one chat",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 900;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE7F3F7), Color(0xFFF7FBFD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 900 : double.infinity,
                ),
                child: Column(
                  children: [
                    // ===== منطقة الرسائل =====
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isWide ? 16 : 0,
                          vertical: isWide ? 12 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F1F5),
                          borderRadius: isWide
                              ? BorderRadius.circular(18)
                              : BorderRadius.zero,
                          boxShadow: isWide
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: _buildMessagesBody(),
                      ),
                    ),

                    // ===== شريط الإدخال =====
                    _buildInputBar(isWide: isWide),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessagesBody() {
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
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          "No messages yet. Say hi 👋",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final m = _messages[index];

        final from = (m['from'] as Map?)
                ?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final isMine = from['_id']?.toString() == _myUserId;

        final text = (m['text'] ?? '').toString();
        final attachmentUrl = (m['attachmentUrl'] ?? '').toString();
        final attachmentName = (m['attachmentName'] ?? '').toString();
        final createdAt = (m['createdAt'] ?? '').toString();

        return _MessageBubble(
          isMine: isMine,
          text: text,
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
          timestamp: createdAt,
        );
      },
    );
  }

  Widget _buildInputBar({required bool isWide}) {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _sending ? null : _pickAndSendAttachment,
              icon: const Icon(Icons.attach_file),
              color: _brandDark,
              tooltip: "Attach file",
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Type a message...",
                  ),
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _sending ? Colors.grey : _brand,
              child: IconButton(
                icon: const Icon(Icons.send, size: 18),
                color: Colors.white,
                onPressed: _sending ? null : _sendTextMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isMine;
  final String text;
  final String attachmentUrl;
  final String attachmentName;
  final String timestamp;

  static const Color _brand = Color(0xFF62C6D9);

  const _MessageBubble({
    required this.isMine,
    required this.text,
    required this.attachmentUrl,
    required this.attachmentName,
    required this.timestamp,
  });

  bool get hasAttachment => attachmentUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bgColor = isMine ? _brand : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;
    final attachIconColor = isMine ? Colors.white : const Color(0xFF285E6E);
    final tsColor =
        isMine ? Colors.white.withOpacity(0.7) : Colors.grey.shade500;

    final String tsShort = timestamp.isNotEmpty
        ? (timestamp.length >= 16
            ? timestamp.substring(0, 16)
            : timestamp)
        : "";

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isMine ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
                isMine ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (text.isNotEmpty)
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),
              ),
            if (hasAttachment) ...[
              if (text.isNotEmpty) const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.tryParse(attachmentUrl);
                  if (uri != null) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMine
                        ? Colors.white.withOpacity(0.16)
                        : const Color(0xFFE3EDF7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insert_drive_file,
                        size: 18,
                        color: attachIconColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          attachmentName.isNotEmpty
                              ? attachmentName
                              : 'Attachment',
                          style: TextStyle(
                            color: textColor,
                            decoration: TextDecoration.underline,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            if (tsShort.isNotEmpty)
              Text(
                tsShort,
                style: TextStyle(
                  color: tsColor,
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
