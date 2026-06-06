import '../theme/phase_theme.dart';

class CycleCalculator {
  static int cycleDay(DateTime startDate) {
    final today = DateTime.now();
    return today.difference(startDate).inDays + 1;
  }

  static CyclePhase phaseFromDay(int day, {int periodDuration = 5}) {
    if (day <= periodDuration) return CyclePhase.menstrual;
    if (day <= 13)             return CyclePhase.follicular;
    if (day <= 16)             return CyclePhase.ovulation;
    return CyclePhase.luteal;
  }

  static CyclePhase currentPhase(Map<String, dynamic>? cycle, Map<String, dynamic>? profile) {
    if (cycle == null) return CyclePhase.unknown;
    final start = DateTime.tryParse(cycle['start_date'] ?? '');
    if (start == null) return CyclePhase.unknown;
    final day = cycleDay(start);
    final pd = (profile?['avg_period_duration'] as int?) ?? 5;
    return phaseFromDay(day, periodDuration: pd);
  }
}