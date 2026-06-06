import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/phase_theme.dart';
import '../../core/utils/cycle_calculator.dart';
import 'supabase_provider.dart';

final latestCycleProvider = StreamProvider((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return const Stream.empty();

  return supabase
      .from('cycles')
      .stream(primaryKey: ['id'])
      .map((rows) {
        final userRows = rows.where((r) => r['user_id'] == user.id).toList();
        userRows.sort((a, b) =>
            (b['start_date'] as String).compareTo(a['start_date'] as String));
        return userRows.isNotEmpty ? userRows.first : null;
      });
});

final currentPhaseProvider = Provider<CyclePhase>((ref) {
  final cycleAsync = ref.watch(latestCycleProvider);
  return cycleAsync.when(
    data: (cycle) {
      if (cycle == null) return CyclePhase.unknown;
      final startDate = DateTime.tryParse(cycle['start_date'] ?? '');
      if (startDate == null) return CyclePhase.unknown;
      final day = CycleCalculator.cycleDay(startDate);
      final profile = ref.read(userProfileProvider).value;
      return CycleCalculator.phaseFromDay(
        day,
        periodDuration: profile?['avg_period_duration'] ?? 5,
      );
    },
    loading: () => CyclePhase.unknown,
    error: (_, __) => CyclePhase.unknown,
  );
});
