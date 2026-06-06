import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/supabase_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  int _cycleLength = 28;
  int _periodDays = 5;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _loadProfile(Map<String, dynamic>? profile) {
    if (_initialized || profile == null) return;
    _nameCtrl.text = profile['full_name'] as String? ?? '';
    _cycleLength = profile['avg_cycle_length'] as int? ?? 28;
    _periodDays = profile['avg_period_duration'] as int? ?? 5;
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final sb = ref.read(supabaseProvider);
      final user = sb.auth.currentUser!;
      await sb.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'avg_cycle_length': _cycleLength,
        'avg_period_duration': _periodDays,
      }).eq('id', user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Color(0xFF4ECDC4),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.menstrual),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    _loadProfile(profile);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textSub),
          onPressed: () => context.go(RouteNames.profile),
        ),
        title: const Text('Settings', style: TextStyle(
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary))
                : const Text('Save', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Profile',
              style: TextStyle(
                  color: AppTheme.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 24),
          const Text('Cycle',
              style: TextStyle(
                  color: AppTheme.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _SliderTile(
            label: 'Average cycle length',
            value: _cycleLength.toDouble(),
            min: 21,
            max: 45,
            suffix: '$_cycleLength days',
            onChanged: (v) => setState(() => _cycleLength = v.round()),
          ),
          _SliderTile(
            label: 'Period duration',
            value: _periodDays.toDouble(),
            min: 2,
            max: 10,
            suffix: '$_periodDays days',
            onChanged: (v) => setState(() => _periodDays = v.round()),
          ),
          const SizedBox(height: 24),
          const Divider(color: AppTheme.border),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: AppTheme.menstrual),
            title: const Text('Sign out',
                style: TextStyle(color: AppTheme.menstrual)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go(RouteNames.login);
            },
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label, suffix;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14)),
              Text(suffix,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            activeColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
