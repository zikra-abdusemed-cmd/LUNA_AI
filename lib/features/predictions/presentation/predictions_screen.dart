import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/phase_theme.dart';
import '../../../../shared/providers/supabase_provider.dart';

class PredictionsScreen extends ConsumerStatefulWidget {
  const PredictionsScreen({super.key});
  @override
  ConsumerState<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends ConsumerState<PredictionsScreen> {
  List<Map<String, dynamic>>? _predictions;
  bool _loading = true;
  int  _selected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sb = ref.read(supabaseProvider);
      final res = await sb.functions.invoke('generate_predictions');
      final data = res.data as Map<String, dynamic>;
      final preds = (data['predictions'] as List?)
          ?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() { _predictions = preds; _loading = false; });
    } catch (e) {
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
          icon: const Icon(Icons.arrow_back, color: AppTheme.textSub),
          onPressed: () => context.go(RouteNames.wellnessTwin),
        ),
        title: const Text('Future Self', style: TextStyle(
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSub),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _predictions == null || _predictions!.isEmpty
          ? _EmptyPredictions()
          : _PredictionsBody(
        predictions: _predictions!,
        selected: _selected,
        onSelect: (i) => setState(() => _selected = i),
      ),
    );
  }
}

class _PredictionsBody extends StatelessWidget {
  final List<Map<String, dynamic>> predictions;
  final int selected;
  final ValueChanged<int> onSelect;
  const _PredictionsBody({required this.predictions, required this.selected,
    required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final sel = predictions.isNotEmpty && selected < predictions.length
        ? predictions[selected]
        : null;

    return Column(children: [
      // Horizontal day scroll
      SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: predictions.length,
          itemBuilder: (context, i) {
            final p = predictions[i];
            final phase = CyclePhaseExt.fromString(p['phase'] as String? ?? 'unknown');
            final isSelected = i == selected;
            final date = DateTime.tryParse(p['date'] as String? ?? '');
            final dayName = date != null
                ? const ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][date.weekday % 7]
                : '?';
            final dayNum = date?.day ?? 0;

            return GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58, margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? phase.color.withOpacity(0.25) : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? phase.color : AppTheme.border,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dayName, style: TextStyle(
                        color: isSelected ? phase.color : AppTheme.textSub,
                        fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('$dayNum', style: TextStyle(
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSub,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
                        fontSize: 18)),
                    Text(phase.emoji, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      // Detail card
      if (sel != null)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _DayDetailCard(prediction: sel),
          ),
        ),
    ]);
  }
}

class _DayDetailCard extends StatelessWidget {
  final Map<String, dynamic> prediction;
  const _DayDetailCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final phase = CyclePhaseExt.fromString(
        prediction['phase'] as String? ?? 'unknown');
    final energy = (prediction['predicted_energy'] as num?)?.toDouble() ?? 5.0;
    final mood   = (prediction['predicted_mood'] as num?)?.toDouble() ?? 5.0;
    final symptoms = (prediction['likely_symptoms'] as List?)
        ?.cast<String>() ?? [];
    final isProd = prediction['is_productivity_window'] == true;
    final narrative = prediction['narrative'] as String?;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Phase banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [phase.color.withOpacity(0.3), phase.color.withOpacity(0.05)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: phase.color.withOpacity(0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(phase.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(phase.name, style: TextStyle(color: phase.color,
                  fontWeight: FontWeight.w700, fontSize: 18)),
              Text('Day ${prediction['cycle_day']}',
                  style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
            ]),
            const Spacer(),
            if (isProd)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.follicular.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.follicular.withOpacity(0.4)),
                ),
                child: const Text('🚀 Peak', style: TextStyle(
                    color: AppTheme.follicular, fontSize: 11,
                    fontWeight: FontWeight.w700)),
              ),
          ]),
          if (narrative != null) ...[
            const SizedBox(height: 12),
            Text(narrative, style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 14, height: 1.5)),
          ],
        ]),
      ),

      const SizedBox(height: 16),

      // Metrics grid
      Row(children: [
        Expanded(child: _MetricCard(
          label: 'Energy', value: energy,
          color: AppTheme.follicular, icon: '⚡',
        )),
        const SizedBox(width: 12),
        Expanded(child: _MetricCard(
          label: 'Mood', value: mood,
          color: AppTheme.primary, icon: '🌙',
        )),
      ]),

      if (symptoms.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Possible symptoms', style: TextStyle(
                color: AppTheme.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: symptoms.map((s) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.menstrual.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.menstrual.withOpacity(0.3)),
                  ),
                  child: Text(s.replaceAll('_', ' '), style: const TextStyle(
                      color: AppTheme.menstrual, fontSize: 12)),
                )
            ).toList()),
          ]),
        ),
      ],
    ]);
  }
}

class _MetricCard extends StatelessWidget {
  final String label, icon;
  final double value;
  final Color color;
  const _MetricCard({required this.label, required this.value,
    required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border, width: 0.5),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value.toStringAsFixed(1),
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 28)),
      Text('/10', style: TextStyle(color: color.withOpacity(0.6), fontSize: 12)),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: value / 10.0,
        backgroundColor: AppTheme.border,
        color: color,
        minHeight: 3,
        borderRadius: BorderRadius.circular(2),
      ),
    ]),
  );
}

class _EmptyPredictions extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔮', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text('Log your period first', style: TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Predictions are based on your cycle data.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSub, fontSize: 14)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go(RouteNames.cycleCalendar),
          child: const Text('Log My Period'),
        ),
      ]),
    ),
  );
}