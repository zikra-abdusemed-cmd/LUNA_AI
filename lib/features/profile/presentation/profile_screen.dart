import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/supabase_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final user    = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: const Text('Profile', style: TextStyle(
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        actions: [
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go(RouteNames.login);
            },
            child: const Text('Sign out', style: TextStyle(color: AppTheme.textSub)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar + name
          Center(child: Column(children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.primary.withOpacity(0.4),
                  AppTheme.primaryDeep.withOpacity(0.1),
                ]),
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: const Center(child: Text('🌙', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 12),
            Text(profile?['full_name'] ?? 'Luna User',
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800, fontSize: 20)),
            Text(user?.email ?? '',
                style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
          ])),

          const SizedBox(height: 32),

          // Stats tiles
          Row(children: [
            Expanded(child: _StatTile(
              label: 'Cycle length',
              value: '${profile?['avg_cycle_length'] ?? 28} days',
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(
              label: 'Period duration',
              value: '${profile?['avg_period_duration'] ?? 5} days',
            )),
          ]),

          const SizedBox(height: 24),

          // Menu tiles
          _MenuTile(
            icon: Icons.calendar_today_outlined,
            label: 'Cycle calendar',
            onTap: () => context.go(RouteNames.cycleCalendar),
          ),
          _MenuTile(
            icon: Icons.mood,
            label: 'Log mood',
            onTap: () => context.go(RouteNames.moodLog),
          ),
          _MenuTile(
            icon: Icons.insights,
            label: 'Wellness Twin',
            onTap: () => context.go(RouteNames.wellnessTwin),
          ),
          _MenuTile(
            icon: Icons.auto_awesome,
            label: 'Future predictions',
            onTap: () => context.go(RouteNames.predictions),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => context.go(RouteNames.settings),
          ),

          const SizedBox(height: 16),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 8),

          _MenuTile(
            icon: Icons.logout,
            label: 'Sign out',
            color: AppTheme.menstrual,
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

class _StatTile extends StatelessWidget {
  final String label, value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border, width: 0.5),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700, fontSize: 18)),
    ]),
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.label,
    required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: color ?? AppTheme.textSub, size: 20),
    title: Text(label, style: TextStyle(
        color: color ?? AppTheme.textPrimary, fontSize: 15)),
    trailing: const Icon(Icons.chevron_right, color: AppTheme.textSub, size: 18),
    onTap: onTap,
  );
}