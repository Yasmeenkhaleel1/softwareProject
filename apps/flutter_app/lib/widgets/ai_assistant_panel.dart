import 'package:flutter/material.dart';
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

  final List<_AiMessage> _messages = [
    _AiMessage(
      fromBot: true,
      text:
          "Hi 👋 I'm your smart assistant.\nI can help you with bookings, payments, and how LostTreasures works.",
      createdAt: DateTime.now(),
    ),
  ];

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
      // ممكن ترسلي context بسيط لاحقًا (آخر حجز، userId، إلخ)
      final answer = await ApiService.askAssistant(
        question: text,
      );

      setState(() {
        _messages.add(
          _AiMessage(
            fromBot: true,
            text: answer,
            createdAt: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          _AiMessage(
            fromBot: true,
            text:
                "Sorry, something went wrong while contacting the assistant.\nDetails: $e",
            createdAt: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // عرض البانل (ويب) – ثابت تقريبًا، بس responsive شوي
    final double panelWidth = 420;

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 24, bottom: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: panelWidth,
            maxHeight: 560,
          ),
          child: Material(
            elevation: 18,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFEBF8FF),
                    Color(0xFFFDFEFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // ===== Header =====
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Smart Assistant",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Ask me anything about your bookings & payments",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: "Close",
                        ),
                      ],
                    ),
                  ),

                  // ===== Suggestions row =====
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: Colors.white.withOpacity(0.8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SuggestionChip(
                            label: "How to book a session?",
                            onTap: () {
                              _controller.text =
                                  "How can I book a new session with an expert?";
                              _send();
                            },
                          ),
                          const SizedBox(width: 8),
                          _SuggestionChip(
                            label: "Payment & refund rules",
                            onTap: () {
                              _controller.text =
                                  "Explain the payment and refund rules for bookings.";
                              _send();
                            },
                          ),
                          const SizedBox(width: 8),
                          _SuggestionChip(
                            label: "My upcoming bookings",
                            onTap: () {
                              _controller.text =
                                  "What are my upcoming bookings and their status?";
                              _send();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // ===== Messages list =====
                  Expanded(
                    child: Container(
                      color: _bg,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _MessageBubble(message: msg);
                        },
                      ),
                    ),
                  ),

                  // ===== Input area =====
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: "Ask me anything...",
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 40,
                          width: 40,
                          child: FloatingActionButton(
                            heroTag: "assistantSend",
                            backgroundColor: _sending
                                ? Colors.grey.shade400
                                : _brandDark,
                            onPressed: _sending ? null : _send,
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================
//  Models + Widgets مساعدة
// =========================

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
    final alignment =
        isBot ? Alignment.centerLeft : Alignment.centerRight;
    final bg = isBot ? Colors.white : const Color(0xFF62C6D9);
    final textColor = isBot ? const Color(0xFF0F172A) : Colors.white;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 320,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isBot ? const Radius.circular(4) : const Radius.circular(16),
              bottomRight:
                  isBot ? const Radius.circular(16) : const Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: textColor,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F3F8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFB6D6E4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bolt_outlined,
              size: 14,
              color: Color(0xFF285E6E),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF285E6E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
