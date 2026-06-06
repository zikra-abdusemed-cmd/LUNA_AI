import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl   = PageController();
  final _nameCtrl   = TextEditingController();
  int _page         = 0;
  int _cycleLength  = 28;
  int _periodDays   = 5;
  bool _loading     = false;

  final _goals = <String>{};
  final _allGoals = [
    '💪 Build energy', '😴 Better sleep', '🎯 Reduce stress',
    '📅 Plan smarter', '🌿 Mindfulness', '💧 Stay hydrated',
  ];

  void _next() {
    if (_page < 3) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _page++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    final sb = Supabase.instance.client;
    final user = sb.auth.currentUser!;
    await sb.from('profiles').update({
      'full_name': _nameCtrl.text.trim(),
      'avg_cycle_length': _cycleLength,
      'avg_period_duration': _periodDays,
      'goals': _goals.toList(),
      'onboarding_completed': true,
    }).eq('id', user.id);
    if (mounted) context.go(RouteNames.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Progress
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: List.generate(4, (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= _page ? AppTheme.primary : AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ))),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(nameCtrl: _nameCtrl),
                  _CyclePage(
                    cycleLength: _cycleLength,
                    periodDays: _periodDays,
                    onCycleChanged: (v) => setState(() => _cycleLength = v),
                    onPeriodChanged: (v) => setState(() => _periodDays = v),
                  ),
                  _GoalsPage(
                    allGoals: _allGoals,
                    selected: _goals,
                    onToggle: (g) => setState(() =>
                    _goals.contains(g) ? _goals.remove(g) : _goals.add(g)),
                  ),
                  const _ReadyPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _next,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(_page < 3 ? 'Continue' : 'Start My Journey'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final TextEditingController nameCtrl;
  const _WelcomePage({required this.nameCtrl});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🌙', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 20),
      const Text('Hi, I\'m Luna', style: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      const SizedBox(height: 8),
      const Text('Your AI wellness copilot. What should I call you?',
          style: TextStyle(fontSize: 15, color: AppTheme.textSub)),
      const SizedBox(height: 40),
      TextField(
        controller: nameCtrl,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(labelText: 'Your name'),
        textCapitalization: TextCapitalization.words,
      ),
    ]),
  );
}

class _CyclePage extends StatelessWidget {
  final int cycleLength, periodDays;
  final ValueChanged<int> onCycleChanged, onPeriodChanged;
  const _CyclePage({required this.cycleLength, required this.periodDays,
    required this.onCycleChanged, required this.onPeriodChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('📅', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 20),
      const Text('Your cycle', style: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      const SizedBox(height: 8),
      const Text('Luna uses this to calculate your phases. You can update this later.',
          style: TextStyle(fontSize: 14, color: AppTheme.textSub)),
      const SizedBox(height: 40),
      _SliderTile(
        label: 'Average cycle length',
        value: cycleLength.toDouble(),
        unit: 'days',
        min: 21, max: 45,
        onChanged: (v) => onCycleChanged(v.round()),
      ),
      const SizedBox(height: 24),
      _SliderTile(
        label: 'Average period duration',
        value: periodDays.toDouble(),
        unit: 'days',
        min: 1, max: 10,
        onChanged: (v) => onPeriodChanged(v.round()),
      ),
    ]),
  );
}

class _SliderTile extends StatelessWidget {
  final String label, unit;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _SliderTile({required this.label, required this.value,
    required this.unit, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
        Text('${value.round()} $unit',
            style: const TextStyle(color: AppTheme.primary,
                fontWeight: FontWeight.w700, fontSize: 18)),
      ]),
      Slider(
        value: value, min: min, max: max,
        activeColor: AppTheme.primary,
        inactiveColor: AppTheme.border,
        onChanged: onChanged,
      ),
    ],
  );
}

class _GoalsPage extends StatelessWidget {
  final List<String> allGoals;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _GoalsPage({required this.allGoals, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🎯', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 20),
      const Text('Your goals', style: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      const SizedBox(height: 8),
      const Text('Luna will tailor your experience to what matters to you.',
          style: TextStyle(fontSize: 14, color: AppTheme.textSub)),
      const SizedBox(height: 32),
      Wrap(spacing: 10, runSpacing: 10, children: allGoals.map((g) {
        final sel = selected.contains(g);
        return GestureDetector(
          onTap: () => onToggle(g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppTheme.primary.withOpacity(0.2) : AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
            ),
            child: Text(g, style: TextStyle(
                color: sel ? AppTheme.primary : AppTheme.textSub, fontSize: 14)),
          ),
        );
      }).toList()),
    ]),
  );
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('✨', style: TextStyle(fontSize: 72)),
      const SizedBox(height: 24),
      const Text('You\'re all set!', style: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      const SizedBox(height: 12),
      const Text('Luna is ready to learn your patterns and help you thrive.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppTheme.textSub, height: 1.5)),
      const SizedBox(height: 32),
      ...[
        '🌙 Phase-aware recommendations',
        '🤖 Agentic task planning',
        '📊 Wellness insights over time',
        '🎙️ Voice-powered journaling',
      ].map((f) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const SizedBox(width: 20),
          Text(f, style: const TextStyle(color: AppTheme.textSub, fontSize: 15)),
        ]),
      )),
    ]),
  );
}