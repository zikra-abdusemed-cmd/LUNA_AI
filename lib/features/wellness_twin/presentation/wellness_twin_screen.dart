import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/supabase_provider.dart';

class WellnessTwinScreen extends ConsumerWidget {
  const WellnessTwinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sb   = ref.watch(supabaseProvider);
    final user = sb.auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: const Text('Wellness Twin', style: TextStyle(
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSub),
            tooltip: 'Regenerate insights',
            onPressed: () async {
              final sb2 = ref.read(supabaseProvider);
              await sb2.functions.invoke('generate_wellness_insights');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✓ Insights updated'),
                  backgroundColor: Color(0xFF4ECDC4),
                ));
              }
            },
          ),
        ],
      ),
      body: user == null ? const Center(child: Text('Not logged in'))
          : FutureBuilder(
        future: Future.wait([
          sb.from('wellness_insights')
              .select()
              .eq('user_id', user.id)
              .eq('is_active', true)
              .order('insight_date', ascending: false),
          sb.from('wellness_scores')
              .select()
              .eq('user_id', user.id)
              .order('score_date', ascending: false)
              .limit(14),
        ]),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final results = snap.data as List?;
          final insights = (results?[0] as List?)
              ?.cast<Map<String, dynamic>>() ?? [];
          final scores = (results?[1] as List?)
              ?.cast<Map<String, dynamic>>() ?? [];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Twin header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.luteal.withOpacity(0.3),
                      AppTheme.primaryDeep.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.luteal.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Text('🧬', style: TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Wellness Twin', style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800, fontSize: 18)),
                      SizedBox(height: 4),
                      Text('Patterns discovered from your logged data.',
                          style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
                    ],
                  )),
                ]),
              ),

              if (insights.isEmpty) ...[
                const SizedBox(height: 40),
                _EmptyInsights(),
              ] else ...[
                const SizedBox(height: 24),
                const Text('Discovered patterns', style: TextStyle(
                    color: AppTheme.textSub, fontSize: 13,
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...insights.map((i) => _InsightCard(insight: i)),
              ],

              if (scores.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('14-day wellness trend', style: TextStyle(
                    color: AppTheme.textSub, fontSize: 13,
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _ScoreSparkline(scores: scores.reversed.toList()),
              ],

              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.go(RouteNames.predictions),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('See Future Predictions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> insight;
  const _InsightCard({required this.insight});

  static const _typeIcons = {
    'sleep_pattern': '😴',
    'mood_pattern': '🎭',
    'energy_pattern': '⚡',
    'symptom_pattern': '🩺',
    'productivity_pattern': '🚀',
    'cycle_correlation': '🔄',
  };

  @override
  Widget build(BuildContext context) {
    final type = insight['insight_type'] as String? ?? 'cycle_correlation';
    final confidence = ((insight['confidence_score'] as num?)?.toDouble() ?? 0.7);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_typeIcons[type] ?? '✨',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(insight['title'] ?? '',
              style: const TextStyle(color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.follicular.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${(confidence * 100).round()}%', style: const TextStyle(
                color: AppTheme.follicular, fontSize: 10,
                fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(insight['content'] ?? '',
            style: const TextStyle(color: AppTheme.textSub, fontSize: 13, height: 1.5)),
      ]),
    );
  }
}

class _ScoreSparkline extends StatelessWidget {
  final List<Map<String, dynamic>> scores;
  const _ScoreSparkline({required this.scores});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: scores.map((s) {
          final score = (s['overall_score'] as int?) ?? 0;
          final height = (score / 100.0 * 60).clamp(4.0, 60.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: _barColor(score),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${score}', style: const TextStyle(
                      color: AppTheme.textSub, fontSize: 9)),
                ],
              ),
            ),
          );
        }).toList()),
      ]),
    );
  }

  Color _barColor(int s) {
    if (s >= 70) return AppTheme.follicular;
    if (s >= 50) return AppTheme.ovulation;
    return AppTheme.menstrual;
  }
}

class _EmptyInsights extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        const Text('🌱', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text('Insights loading...', style: TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Log your mood for 7+ days to unlock Wellness Twin patterns.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSub, fontSize: 14, height: 1.5)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go(RouteNames.moodLog),
          child: const Text('Log Today\'s Mood'),
        ),
      ]),
    ),
  );
}