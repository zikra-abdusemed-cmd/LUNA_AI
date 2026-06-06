import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/supabase_provider.dart';

class CycleCalendarScreen extends ConsumerStatefulWidget {
  const CycleCalendarScreen({super.key});
  @override
  ConsumerState<CycleCalendarScreen> createState() => _CycleCalendarScreenState();
}

class _CycleCalendarScreenState extends ConsumerState<CycleCalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  bool _loading = false;

  Future<void> _logPeriodStart(DateTime date) async {
    setState(() => _loading = true);
    final sb = ref.read(supabaseProvider);
    final user = sb.auth.currentUser!;
    try {
      await sb.from('cycles').upsert({
        'user_id': user.id,
        'start_date': date.toIso8601String().split('T')[0],
      }, onConflict: 'user_id,start_date');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Period start logged'),
          backgroundColor: Color(0xFF4ECDC4),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sb   = ref.watch(supabaseProvider);
    final user = sb.auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textSub),
          onPressed: () => context.go(RouteNames.dashboard),
        ),
        title: const Text('Cycle Tracker', style: TextStyle(
            fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Calendar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focused,
                selectedDayPredicate: (d) => isSameDay(_selected, d),
                onDaySelected: (selected, focused) =>
                    setState(() { _selected = selected; _focused = focused; }),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  defaultTextStyle: const TextStyle(color: AppTheme.textPrimary),
                  weekendTextStyle: const TextStyle(color: AppTheme.textPrimary),
                  selectedDecoration: const BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.3), shape: BoxShape.circle),
                  todayTextStyle: const TextStyle(color: AppTheme.primary,
                      fontWeight: FontWeight.w700),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700),
                  leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.textSub),
                  rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.textSub),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: AppTheme.textSub, fontSize: 12),
                  weekendStyle: TextStyle(color: AppTheme.textSub, fontSize: 12),
                ),
              ),
            ),

            if (_selected != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selected!.day} ${_monthName(_selected!.month)} ${_selected!.year}',
                          style: const TextStyle(color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: ElevatedButton.icon(
                          onPressed: _loading ? null : () => _logPeriodStart(_selected!),
                          icon: const Text('🩸', style: TextStyle(fontSize: 16)),
                          label: const Text('Period started on this day'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.menstrual,
                            foregroundColor: Colors.white,
                          ),
                        )),
                      ],
                    ),
                  ),
                ]),
              ),

            // Cycle history
            if (user != null)
              FutureBuilder(
                future: sb.from('cycles')
                    .select()
                    .eq('user_id', user.id)
                    .order('start_date', ascending: false)
                    .limit(6),
                builder: (context, snap) {
                  final cycles = (snap.data as List?)
                      ?.cast<Map<String, dynamic>>() ?? [];
                  if (cycles.isEmpty) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recent cycles', style: TextStyle(
                            color: AppTheme.textSub, fontWeight: FontWeight.w600,
                            fontSize: 13)),
                        const SizedBox(height: 10),
                        ...cycles.map((c) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border, width: 0.5),
                          ),
                          child: Row(children: [
                            const Text('🩸', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Text(c['start_date'] ?? '',
                                style: const TextStyle(color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            if (c['cycle_length'] != null)
                              Text('${c['cycle_length']} days',
                                  style: const TextStyle(color: AppTheme.textSub,
                                      fontSize: 12)),
                          ]),
                        )),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) => const ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}