import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/fcm_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;
  String? _sendResult;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snap.docs.map((d) => {...d.data(), 'uid': d.id}).toList();
  }

  Future<void> _sendPushToAll() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) return;
    setState(() { _sending = true; _sendResult = null; });
    try {
      // Guardar el mensaje en Firestore para que Cloud Function lo dispare
      await FirebaseFirestore.instance.collection('push_broadcasts').add({
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'sentAt': FieldValue.serverTimestamp(),
        'topic': 'all_users',
      });
      await FcmService().subscribeTopic('all_users');
      _titleCtrl.clear();
      _bodyCtrl.clear();
      setState(() => _sendResult = 'Notificación encolada. Se enviará en segundos.');
    } catch (e) {
      setState(() => _sendResult = 'Error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Administrador')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snap) {
          final users = snap.data ?? [];
          final total = users.length;
          final withToken = users.where((u) => u['fcmToken'] != null).length;
          final plans = <String, int>{};
          for (final u in users) {
            final plan = u['plan'] as String? ?? 'free';
            plans[plan] = (plans[plan] ?? 0) + 1;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Stats
              const _SectionTitle('Estadísticas'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatCard('Usuarios', '$total', Icons.people_outline),
                  const SizedBox(width: 8),
                  _StatCard('Con push', '$withToken', Icons.notifications_active_outlined),
                  const SizedBox(width: 8),
                  _StatCard('Pro', '${plans['pro'] ?? 0}', Icons.star_outline),
                ],
              ),
              const SizedBox(height: 24),

              // Push masivo
              const _SectionTitle('Notificación push a todos'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    _Field(controller: _titleCtrl, hint: 'Título'),
                    const SizedBox(height: 8),
                    _Field(controller: _bodyCtrl, hint: 'Mensaje', maxLines: 3),
                    const SizedBox(height: 12),
                    if (_sendResult != null) ...[
                      Text(_sendResult!,
                          style: const TextStyle(color: AppTheme.bullish, fontSize: 12)),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _sendPushToAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Icon(Icons.send, size: 16),
                        label: Text(_sending ? 'Enviando...' : 'Enviar a todos'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Lista de usuarios
              const _SectionTitle('Usuarios registrados'),
              const SizedBox(height: 8),
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              else
                ...users.map((u) => _UserTile(user: u)),
            ],
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ?? 'Sin nombre';
    final email = user['email'] as String? ?? '';
    final plan = user['plan'] as String? ?? 'free';
    final createdAt = user['createdAt'] as String?;
    DateTime? dt;
    if (createdAt != null) dt = DateTime.tryParse(createdAt);
    final hasPush = user['fcmToken'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                if (dt != null)
                  Text('Registro: ${DateFormat('dd/MM/yy').format(dt)}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: plan == 'pro'
                      ? AppTheme.warning.withValues(alpha: 0.15)
                      : AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  plan.toUpperCase(),
                  style: TextStyle(
                    color: plan == 'pro' ? AppTheme.warning : AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                hasPush ? Icons.notifications_active : Icons.notifications_off,
                size: 14,
                color: hasPush ? AppTheme.bullish : AppTheme.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12,
          fontWeight: FontWeight.w600, letterSpacing: 1));
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _Field({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textSecondary),
          filled: true,
          fillColor: AppTheme.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.cardBorder),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
