import 'package:flutter/material.dart';
import 'dart:convert';
import '../../api/api_service.dart';

class AiAssistantPanel extends StatefulWidget {
  final VoidCallback onClose;
  final String userName;
  final String userId;

  const AiAssistantPanel({
    super.key,
    required this.onClose,
    required this.userName,
    required this.userId,
  });

  @override
  State<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends State<AiAssistantPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;

  /// جلسة المحادثة من السيرفر
  String? _sessionId;

  // Initializing with the welcome message
  final List<_AiMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    
    _messages.add(
      _AiMessage(
        fromBot: true,
        text:
            "Hi 👋 I'm your smart assistant.\nI can help you with bookings, payments, and how LostTreasures works.",
        createdAt: DateTime.now(),
      ),
    );
  }

  static const Color _brand = Color(0xFF62C6D9);
  static const Color _brandDark = Color(0xFF285E6E);
  static const Color _bg = Color(0xFFF4F7FB);

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.add(
        _AiMessage(
          fromBot: false,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final result = await ApiService.askAssistant(
        question: "Please reply in English only.\n$text",
      );

      Map<String, dynamic>? data;

      if (result is Map<String, dynamic>) {
        data = result as Map<String, dynamic>?;
      } else if (result is String) {
        // مسحاولة تحويل النص إلى JSON إذا كان السيرفر يرجع JSON كنص
        try {
          final decoded = jsonDecode(result);
          if (decoded is Map<String, dynamic>) data = decoded;
        } catch (_) {
          // إذا لم يكن JSON، نتركه كنص عادي
        }
      }

      String answerText;
      if (data != null) {
        // استخراج الرد من البيانات
        answerText = (data["reply"] ?? data["response"] ?? data["answer"] ?? "").toString();
        
        // استخراج sessionId من البيانات إذا وجد
        final sid = data["sessionId"] ?? data["session_id"] ?? data["session"];
        if (sid != null) {
          _sessionId = sid.toString();
        }
      } else {
        answerText = result.toString();
      }

      if (mounted) {
        setState(() {
          _messages.add(
            _AiMessage(
              fromBot: true,
              text: answerText.isEmpty ? "No reply received." : answerText,
              createdAt: DateTime.now(),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _AiMessage(
              fromBot: true,
              text: "Sorry, I'm having trouble connecting right now.\nDetails: $e",
              createdAt: DateTime.now(),
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    if (!isMobile) {
      const double panelWidth = 420;
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 24, bottom: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: panelWidth,
              maxHeight: 600,
            ),
            child: _buildPanelLayout(isMobile: false),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: size.width,
            maxHeight: size.height * 0.85,
          ),
          child: _buildPanelLayout(isMobile: true),
        ),
      ),
    );
  }

  Widget _buildPanelLayout({required bool isMobile}) {
    return Material(
      elevation: 18,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEBF8FF), Color(0xFFFDFEFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            children: [
              _buildHeader(isMobile),
              _buildSuggestions(),
              const Divider(height: 1),
              Expanded(
                child: Container(
                  color: _bg,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
                ),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final sid = _sessionId;
    final shortSid = (sid != null && sid.length >= 8) ? sid.substring(0, 8) : "New";
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF62C6D9), Color(0xFF2F8CA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Smart Assistant (${widget.userName})",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                Text(
                  "Session: $shortSid | Online",
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon:
                Icon(isMobile ? Icons.keyboard_arrow_down : Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white.withOpacity(0.8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SuggestionChip(
              label: "My Bookings",
              onTap: () {
                _controller.text = "Show me my active bookings";
                _send();
              },
            ),
            const SizedBox(width: 8),
            _SuggestionChip(
              label: "Payment Rules",
              onTap: () {
                _controller.text = "How does payment work?";
                _send();
              },
            ),
            const SizedBox(width: 8),
            _SuggestionChip(
              label: "Cancel Policy",
              onTap: () {
                _controller.text = "How can I cancel a booking?";
                _send();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Type a message...",
                  hintStyle: TextStyle(fontSize: 14),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: CircleAvatar(
              backgroundColor: _sending ? Colors.grey : _brandDark,
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Helper Models & Widgets
// --------------------------------------------------------------------------

class _AiMessage {
  final bool fromBot;
  final String text;
  final DateTime createdAt;

  _AiMessage({
    required this.fromBot,
    required this.text,
    required this.createdAt,
  });
}

class _MessageBubble extends StatelessWidget {
  final _AiMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isBot = message.fromBot;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isBot ? Colors.white : const Color(0xFF62C6D9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isBot ? 4 : 16),
            bottomRight: Radius.circular(isBot ? 16 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isBot ? const Color(0xFF0F172A) : Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: const Color(0xFFE5F3F8),
      side: const BorderSide(color: Color(0xFFB6D6E4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      avatar: const Icon(Icons.bolt, size: 16, color: Color(0xFF285E6E)),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF285E6E), fontWeight: FontWeight.w500),
      ),
    );
  }
}