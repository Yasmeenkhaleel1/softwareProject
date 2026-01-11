// lib/pages/change_password_page.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  // Brand
  static const Color _brand = Color(0xFF62C6D9);
  static const Color _accent = Color(0xFF285E6E);
  static const Color _bg = Color(0xFFF4F7FB);

  final _formKey = GlobalKey<FormState>();

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  bool _isStrongPassword(String v) {
    final s = v.trim();
    if (s.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(s);
    final hasNumber = RegExp(r'\d').hasMatch(s);
    return hasLetter && hasNumber;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() => _error = "Please login first.");
      return;
    }

    setState(() => _saving = true);

    try {
      final url = "${ApiConfig.baseUrl}/auth/change-password";
      final body = {
        "currentPassword": _currentCtrl.text.trim(),
        "newPassword": _newCtrl.text.trim(),
        "confirmPassword": _confirmCtrl.text.trim(),
      };

      final res = await http.patch(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      if (res.statusCode >= 400) {
        String msg = "Failed to change password.";
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded["message"] != null) {
            msg = decoded["message"].toString();
          } else if (decoded is Map && decoded["errors"] is List && decoded["errors"].isNotEmpty) {
            msg = (decoded["errors"][0]["msg"] ?? msg).toString();
          }
        } catch (_) {
          // ignore parsing errors
        }
        throw Exception(msg);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Password changed successfully")),
      );

      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception:", "").trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _accent,
        title: const Text(
          "Change Password",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final isMobile = w < 900;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 14 : 24),
                child: isMobile ? _buildMobile() : _buildWebSplit(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWebSplit() {
    return Row(
      children: [
        Expanded(child: _buildHeroCard()),
        const SizedBox(width: 14),
        Expanded(child: _buildFormCard()),
      ],
    );
  }

  Widget _buildMobile() {
    return ListView(
      children: [
        _buildHeroCard(),
        const SizedBox(height: 12),
        _buildFormCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeroCard() {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [_brand, Color(0xFF7DD7E6), _accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GlassPill(
                icon: Icons.verified_user_outlined,
                label: "Account Security",
              ),
              const SizedBox(height: 14),
              const Text(
                "Keep your account safe.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Use a strong password (8+ chars with letters and numbers). "
                "Never share it with anyone.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _TipChip(text: "At least 8 characters"),
                  _TipChip(text: "Letters + numbers"),
                  _TipChip(text: "Unique password"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Update password",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Enter your current password, then choose a new one.",
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),

            if (_error != null) ...[
              _InlineBanner(
                tone: _BannerTone.danger,
                title: "Couldn’t update password",
                message: _error!,
              ),
              const SizedBox(height: 12),
            ],

            _PasswordField(
              label: "Current password",
              controller: _currentCtrl,
              show: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
              validator: (v) {
                if ((v ?? "").trim().isEmpty) return "Current password is required";
                return null;
              },
            ),
            const SizedBox(height: 12),

            _PasswordField(
              label: "New password",
              controller: _newCtrl,
              show: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              helper: "8+ chars, include letters and numbers",
              validator: (v) {
                final s = (v ?? "").trim();
                if (s.isEmpty) return "New password is required";
                if (!_isStrongPassword(s)) return "Use 8+ chars with letters and numbers";
                if (s == _currentCtrl.text.trim()) return "New password must be different";
                return null;
              },
            ),
            const SizedBox(height: 12),

            _PasswordField(
              label: "Confirm new password",
              controller: _confirmCtrl,
              show: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              validator: (v) {
                final s = (v ?? "").trim();
                if (s.isEmpty) return "Please confirm your new password";
                if (s != _newCtrl.text.trim()) return "Passwords do not match";
                return null;
              },
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Icon(Icons.lock_reset),
                label: Text(
                  _saving ? "Saving..." : "Save password",
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 10),
           
          ],
        ),
      ),
    );
  }
}

/*────────────────────────  UI Components  ────────────────────────*/

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({required this.child, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shadowColor: const Color(0x14000000),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GlassPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final String text;
  const _TipChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final String? helper;
  final TextEditingController controller;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.label,
    this.helper,
    required this.controller,
    required this.show,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: show ? "Hide" : "Show",
          onPressed: onToggle,
          icon: Icon(show ? Icons.visibility_off : Icons.visibility),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF244C63).withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF62C6D9).withOpacity(0.85), width: 1.4),
        ),
      ),
    );
  }
}

enum _BannerTone { danger }

class _InlineBanner extends StatelessWidget {
  final _BannerTone tone;
  final String title;
  final String message;

  const _InlineBanner({
    required this.tone,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = const Color(0xFFEB5757);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.error_outline, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF244C63))),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
