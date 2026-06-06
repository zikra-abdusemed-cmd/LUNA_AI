import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/supabase_provider.dart';

class MoodLogScreen extends ConsumerStatefulWidget {
  const MoodLogScreen({super.key});
  @override
  ConsumerState<MoodLogScreen> createState() => _MoodLogScreenState();
}

class _MoodLogScreenState extends ConsumerState<MoodLogScreen> {
  String _mood         = 'calm';
  int    _energy       = 6;
  int    _stress       = 4;
  double _sleep        = 7;
  int    _hydration    = 6;
  int    _activity     = 5;
  final  _symptoms     = <String>{};
  bool   _loading      = false;

  static const _moods = [
    ('happy', '😄'), ('calm', '😌'), ('neutral', '😐'),
    ('energetic', '⚡'), ('content', '☺️'), ('anxious', '😰'),
    ('stressed', '😤'), ('sad', '😔'), ('fatigued', '😴'),
    ('irritable', '😠'), ('hopeful', '🌟'), ('overwhelmed', '🌀'),
  ];

  static const _symptomList = [
    'cramps', 'headache', 'bloating', 'fatigue', 'mood_swings',
    'breast_tenderness', 'acne', 'back_pain', 'nausea', 'insomnia',
  ];

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final sb   = ref.read(supabaseProvider);
      final user = sb.auth.currentUser!;

      // Get current cycle
      final cycleRes = await sb.from('cycles')
          .select('id').eq('user_id', user.id)
          .order('start_date', ascending: false).limit(1).maybeSingle();

      await sb.from('moods').upsert({
        'user_id': user.id,
        'cycle_id': cycleRes?['id'],
        'logged_date': DateTime.now().toIso8601String().split('T')[0],
        'mood': _mood,
        'energy_level': _energy,
        'stress_level': _stress,
        'sleep_hours': _sleep,
        'hydration_glasses': _hydration,
        'activity_level': _activity,
        'symptoms': _symptoms.toList(),
        'source': 'manual',
      }, onConflict: 'user_id,logged_date');

      // Trigger wellness score calculation
      await sb.functions.invoke('calculate_wellness_score', body: {
        'date': DateTime.now().toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Mood logged'),
          backgroundColor: Color(0xFF4ECDC4),
          duration: Duration(seconds: 2),
        ));
        context.go(RouteNames.dashboard);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.menstrual),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textSub),
          onPressed: () => context.go(RouteNames.dashboard),
        ),
        title: const Text('Log Your Day', style: TextStyle(
            fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : const Text('Save', style: TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Mood selector
          _Section(title: 'How are you feeling?', child:
          Wrap(spacing: 10, runSpacing: 10, children: _moods.map((m) {
            final sel = _mood == m.$1;
            return GestureDetector(
              onTap: () => setState(() => _mood = m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primary.withOpacity(0.2) : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: sel ? AppTheme.primary : AppTheme.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(m.$2, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(m.$1, style: TextStyle(
                      color: sel ? AppTheme.primary : AppTheme.textSub,
                      fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                ]),
              ),
            );
          }).toList()),
          ),

          const SizedBox(height: 24),
          _Section(title: 'Energy', child:
          _SliderRow(value: _energy, min: 1, max: 10,
              color: AppTheme.follicular,
              labels: ('Drained', 'Electric'),
              onChanged: (v) => setState(() => _energy = v)),
          ),

          const SizedBox(height: 16),
          _Section(title: 'Stress', child:
          _SliderRow(value: _stress, min: 1, max: 10,
              color: AppTheme.menstrual,
              labels: ('None', 'Extreme'),
              onChanged: (v) => setState(() => _stress = v)),
          ),

          const SizedBox(height: 16),
          _Section(title: 'Sleep', child:
          Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${_sleep.toStringAsFixed(1)} hours',
                  style: const TextStyle(color: AppTheme.primary,
                      fontWeight: FontWeight.w700, fontSize: 18)),
            ]),
            Slider(
              value: _sleep, min: 0, max: 12, divisions: 24,
              activeColor: AppTheme.luteal,
              inactiveColor: AppTheme.border,
              onChanged: (v) => setState(() => _sleep = v),
            ),
          ]),
          ),

          const SizedBox(height: 16),
          _Section(title: 'Hydration (glasses)', child:
          Row(children: List.generate(10, (i) => GestureDetector(
            onTap: () => setState(() => _hydration = i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 28, height: 28, margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: i < _hydration
                    ? AppTheme.follicular.withOpacity(0.3)
                    : AppTheme.bgCard,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: i < _hydration ? AppTheme.follicular : AppTheme.border),
              ),
              child: Center(child: Text('💧',
                  style: TextStyle(fontSize: i < _hydration ? 14 : 10))),
            ),
          ))),
          ),

          const SizedBox(height: 24),
          _Section(title: 'Symptoms (optional)', child:
          Wrap(spacing: 8, runSpacing: 8, children: _symptomList.map((s) {
            final sel = _symptoms.contains(s);
            return GestureDetector(
              onTap: () => setState(() =>
              sel ? _symptoms.remove(s) : _symptoms.add(s)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.menstrual.withOpacity(0.15) : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? AppTheme.menstrual : AppTheme.border),
                ),
                child: Text(s.replaceAll('_', ' '), style: TextStyle(
                    color: sel ? AppTheme.menstrual : AppTheme.textSub,
                    fontSize: 12)),
              ),
            );
          }).toList()),
          ),

          const SizedBox(height: 40),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _loading ? null : _save,
            child: const Text('Save Today\'s Log'),
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: AppTheme.textSub,
          fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 12),
      child,
    ],
  );
}

class _SliderRow extends StatelessWidget {
  final int value;
  final double min, max;
  final Color color;
  final (String, String) labels;
  final ValueChanged<int> onChanged;
  const _SliderRow({required this.value, required this.min, required this.max,
    required this.color, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(labels.$1, style: const TextStyle(color: AppTheme.textSub, fontSize: 11)),
      Text('$value / ${max.toInt()}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
      Text(labels.$2, style: const TextStyle(color: AppTheme.textSub, fontSize: 11)),
    ]),
    Slider(
      value: value.toDouble(), min: min, max: max,
      divisions: (max - min).toInt(),
      activeColor: color, inactiveColor: AppTheme.border,
      onChanged: (v) => onChanged(v.round()),
    ),
  ]);
}