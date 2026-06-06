import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phase_theme.dart';
import '../../../core/utils/cycle_calculator.dart';
import '../../../shared/providers/supabase_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final cycle   = ref.watch(latestCycleProvider).value;
    final phase   = ref.watch(currentPhaseProvider);
    final name    = (profile?['full_name'] as String?)?.split(' ').first ?? 'there';

    int? cycleDay;
    if (cycle != null) {
      final start = DateTime.tryParse(cycle['start_date'] ?? '');
      if (start != null) cycleDay = CycleCalculator.cycleDay(start);
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            backgroundColor: AppTheme.bgDeep,
            title: Row(children: [
              const Text('🌙', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text('Luna', style: TextStyle(
                  fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 20)),
            ]),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppTheme.textSub),
                onPressed: () {},
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Greeting
                Text('Good ${_greeting()}, $name',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text(DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
                const SizedBox(height: 24),

                // Phase hero card
                _PhaseCard(phase: phase, cycleDay: cycleDay,
                    avgCycleLength: (profile?['avg_cycle_length'] as int?) ?? 28),
                const SizedBox(height: 16),

                // Wellness score + quick actions row
                _WellnessScoreSection(),
                const SizedBox(height: 16),

                // Today's AI tip
                _AiTipCard(phase: phase),
                const SizedBox(height: 16),

                // Tasks strip
                _TasksStrip(),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: _QuickLogFab(),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

// ── Phase Card ────────────────────────────────────────────────
class _PhaseCard extends StatelessWidget {
  final CyclePhase phase;
  final int? cycleDay, avgCycleLength;
  const _PhaseCard({required this.phase, this.cycleDay, this.avgCycleLength});

  @override
  Widget build(BuildContext context) {
    final progress = cycleDay != null && avgCycleLength != null
        ? (cycleDay! / avgCycleLength!).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            phase.color.withOpacity(0.25),
            phase.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: phase.color.withOpacity(0.4), width: 1),
      ),
      child: Row(children: [
        // Ring
        SizedBox(
          width: 80, height: 80,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: AppTheme.border,
              color: phase.color,
            ),
            Text(phase.emoji, style: const TextStyle(fontSize: 28)),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: phase.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(phase.name, style: TextStyle(
                    color: phase.color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              if (cycleDay != null) ...[
                const SizedBox(width: 8),
                Text('Day $cycleDay',
                    style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
              ],
            ]),
            const SizedBox(height: 6),
            Text(phase.tagline, style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(phase.advice, style: const TextStyle(
                color: AppTheme.textSub, fontSize: 12, height: 1.4)),
          ],
        )),
      ]),
    );
  }
}

// ── Wellness Score ────────────────────────────────────────────
class _WellnessScoreSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sb   = ref.watch(supabaseProvider);
    final user = sb.auth.currentUser;
    return FutureBuilder<Map<String, dynamic>?>(
      future: user == null
          ? Future<Map<String, dynamic>?>.value(null)
          : sb
              .from('wellness_scores')
              .select()
              .eq('user_id', user.id)
              .order('score_date', ascending: false)
              .limit(1)
              .maybeSingle(),
      builder: (context, snap) {
        final score = snap.data?['overall_score'] as int?;
        final interp = snap.data?['ai_interpretation'] as String?;

        return Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Row(children: [
                Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 56, height: 56,
                    child: CircularProgressIndicator(
                      value: score != null ? score / 100.0 : 0,
                      strokeWidth: 4,
                      backgroundColor: AppTheme.border,
                      color: _scoreColor(score),
                    ),
                  ),
                  Text(score != null ? '$score' : '--',
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wellness Score',
                        style: TextStyle(color: AppTheme.textSub, fontSize: 11)),
                    Text(interp ?? (score == null ? 'Log mood to calculate' : ''),
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 12, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                )),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.go(RouteNames.moodLog),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Column(children: const [
                Icon(Icons.mood, color: AppTheme.primary, size: 24),
                SizedBox(height: 4),
                Text('Log\nMood', textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.primary, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]);
      },
    );
  }

  Color _scoreColor(int? s) {
    if (s == null) return AppTheme.textSub;
    if (s >= 70) return const Color(0xFF4ECDC4);
    if (s >= 50) return AppTheme.ovulation;
    return AppTheme.menstrual;
  }
}

// ── AI Tip Card ───────────────────────────────────────────────
class _AiTipCard extends StatelessWidget {
  final CyclePhase phase;
  const _AiTipCard({required this.phase});

  static final _tips = {
    CyclePhase.menstrual:  '🛁 Try a warm bath tonight to ease any discomfort. Your body is doing significant work — rest is productive.',
    CyclePhase.follicular: '🚀 Your creativity is ramping up. Today is excellent for brainstorming, planning, and starting new projects.',
    CyclePhase.ovulation:  '💬 Schedule your important conversations and presentations today — you\'re at peak communication energy.',
    CyclePhase.luteal:     '✅ Focus on completing existing tasks rather than starting new ones. Your organizational skills are strong right now.',
    CyclePhase.unknown:    '🌙 Log your period to unlock personalized daily tips based on your cycle phase.',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Luna's tip for today",
                style: TextStyle(color: AppTheme.textSub, fontSize: 11)),
            const SizedBox(height: 4),
            Text(_tips[phase] ?? _tips[CyclePhase.unknown]!,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
          ],
        )),
      ]),
    );
  }
}

// ── Tasks Strip ───────────────────────────────────────────────
class _TasksStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sb   = ref.watch(supabaseProvider);
    final user = sb.auth.currentUser;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Upcoming tasks',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary, fontSize: 15)),
        TextButton(
          onPressed: () => context.go(RouteNames.taskBoard),
          child: const Text('See all', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
        ),
      ]),
      FutureBuilder(
        future: user == null ? Future.value(<Map<String, dynamic>>[]) : sb
            .from('tasks')
            .select()
            .eq('user_id', user.id)
            .inFilter('status', ['pending', 'in_progress'])
            .order('due_date')
            .limit(3),
        builder: (context, snap) {
          final tasks = (snap.data as List?)?.cast<Map<String, dynamic>>() ?? [];
          if (tasks.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.auto_awesome, color: AppTheme.textSub, size: 16),
                const SizedBox(width: 8),
                Text('Chat with Luna to create tasks',
                    style: TextStyle(color: AppTheme.textSub.withOpacity(0.7), fontSize: 13)),
              ]),
            );
          }
          return Column(children: tasks.map((t) => _MiniTaskTile(task: t)).toList());
        },
      ),
    ]);
  }
}

class _MiniTaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  const _MiniTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final priority = task['priority'] as String? ?? 'medium';
    final dueDate  = task['due_date'] != null
        ? DateTime.tryParse(task['due_date'])
        : null;
    final colors = {
      'urgent': AppTheme.menstrual,
      'high': AppTheme.ovulation,
      'medium': AppTheme.primary,
      'low': AppTheme.follicular,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(children: [
        Container(width: 3, height: 36,
            decoration: BoxDecoration(
              color: colors[priority] ?? AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task['title'] ?? '', style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          if (dueDate != null)
            Text('Due ${DateFormat('MMM d').format(dueDate)}',
                style: const TextStyle(color: AppTheme.textSub, fontSize: 11)),
        ])),
        if (task['is_ai_generated'] == true)
          const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 14),
      ]),
    );
  }
}

// ── Quick Log FAB ─────────────────────────────────────────────
class _QuickLogFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _showQuickLog(context),
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.black,
      icon: const Icon(Icons.add),
      label: const Text('Log', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  void _showQuickLog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          const Text('What would you like to log?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _LogOption(emoji: '🩸', label: 'Period',
                onTap: () { Navigator.pop(context); context.go(RouteNames.cycleCalendar); }),
            _LogOption(emoji: '😊', label: 'Mood',
                onTap: () { Navigator.pop(context); context.go(RouteNames.moodLog); }),
            _LogOption(emoji: '💬', label: 'Chat',
                onTap: () { Navigator.pop(context); context.go(RouteNames.chat); }),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

class _LogOption extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _LogOption({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
    ]),
  );
}