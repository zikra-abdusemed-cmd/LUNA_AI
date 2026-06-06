import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phase_theme.dart';
import '../../../shared/providers/supabase_provider.dart';

class SuggestionReviewScreen extends ConsumerStatefulWidget {
  const SuggestionReviewScreen({super.key});
  @override
  ConsumerState<SuggestionReviewScreen> createState() =>
      _SuggestionReviewScreenState();
}

class _SuggestionReviewScreenState
    extends ConsumerState<SuggestionReviewScreen> {
  bool _loading = false;
  final Map<String, Set<int>> _approved = {};

  @override
  Widget build(BuildContext context) {
    final sb   = ref.watch(supabaseProvider);
    final user = sb.auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textSub),
          onPressed: () => context.go(RouteNames.taskBoard),
        ),
        title: const Text('Review Suggestions', style: TextStyle(
            fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ),
      body: user == null ? const Center(child: Text('Not logged in'))
          : FutureBuilder(
        future: sb.from('task_suggestions')
            .select()
            .eq('user_id', user.id)
            .eq('status', 'pending')
            .order('created_at', ascending: false),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final suggestions = (snap.data as List?)
              ?.cast<Map<String, dynamic>>() ?? [];
          if (suggestions.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('✅', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                const Text('All caught up!', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 18,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('No pending suggestions',
                    style: TextStyle(color: AppTheme.textSub)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(RouteNames.taskBoard),
                  child: const Text('View Tasks'),
                ),
              ],
            ));
          }
          return _SuggestionList(
            suggestions: suggestions,
            approved: _approved,
            onToggle: (sId, idx) => setState(() {
              _approved.putIfAbsent(sId, () => {});
              if (_approved[sId]!.contains(idx)) {
                _approved[sId]!.remove(idx);
              } else {
                _approved[sId]!.add(idx);
              }
            }),
            onApprove: (suggestion) => _approve(context, suggestion),
            onReject: (suggestion) => _reject(context, suggestion),
            loading: _loading,
          );
        },
      ),
    );
  }

  Future<void> _approve(BuildContext context, Map<String, dynamic> suggestion) async {
    setState(() => _loading = true);
    final sb = ref.read(supabaseProvider);
    final sId = suggestion['id'] as String;
    final allTasks = (suggestion['suggested_tasks'] as List)
        .cast<Map<String, dynamic>>();
    final selectedIndices = _approved[sId] ?? Set.from(
        List.generate(allTasks.length, (i) => i));

    final selected = allTasks
        .asMap()
        .entries
        .where((e) => selectedIndices.contains(e.key))
        .map((e) => e.value)
        .toList();

    try {
      await sb.functions.invoke('approve_task_suggestion', body: {
        'suggestion_id': sId,
        'selected_tasks': selected,
      });
      if (mounted) context.go(RouteNames.taskBoard);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.menstrual),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject(BuildContext context, Map<String, dynamic> suggestion) async {
    final sb = ref.read(supabaseProvider);
    await sb.from('task_suggestions')
        .update({'status': 'rejected'})
        .eq('id', suggestion['id']);
    if (mounted) setState(() {});
  }
}

class _SuggestionList extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final Map<String, Set<int>> approved;
  final Function(String, int) onToggle;
  final Function(Map<String, dynamic>) onApprove, onReject;
  final bool loading;

  const _SuggestionList({
    required this.suggestions, required this.approved,
    required this.onToggle, required this.onApprove,
    required this.onReject, required this.loading,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // Header explainer
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 18),
          const SizedBox(width: 10),
          const Expanded(child: Text(
            'Luna extracted these tasks. Select which ones to add.',
            style: TextStyle(color: AppTheme.textSub, fontSize: 13),
          )),
        ]),
      ),
      ...suggestions.map((s) => _SuggestionCard(
        suggestion: s,
        approvedIndices: approved[s['id']] ??
            Set.from(List.generate(
                (s['suggested_tasks'] as List).length, (i) => i)),
        onToggle: (idx) => onToggle(s['id'], idx),
        onApprove: () => onApprove(s),
        onReject: () => onReject(s),
        loading: loading,
      )),
    ],
  );
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final Set<int> approvedIndices;
  final Function(int) onToggle;
  final VoidCallback onApprove, onReject;
  final bool loading;

  const _SuggestionCard({
    required this.suggestion, required this.approvedIndices,
    required this.onToggle, required this.onApprove,
    required this.onReject, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = (suggestion['suggested_tasks'] as List)
        .cast<Map<String, dynamic>>();
    final reasoning = suggestion['ai_reasoning'] as String? ?? '';
    final phase = suggestion['cycle_phase'] as String? ?? 'unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Text('Luna\'s suggestion (${tasks.length} task${tasks.length > 1 ? 's' : ''})',
                      style: const TextStyle(color: AppTheme.primary,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: CyclePhaseExt.fromString(phase).color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(phase,
                        style: TextStyle(
                            color: CyclePhaseExt.fromString(phase).color,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ]),
                if (reasoning.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(reasoning, style: const TextStyle(
                      color: AppTheme.textSub, fontSize: 12, height: 1.4)),
                ],
              ],
            ),
          ),

          const Divider(color: AppTheme.border, height: 0.5),

          // Task items
          ...tasks.asMap().entries.map((e) {
            final t = e.value;
            final selected = approvedIndices.contains(e.key);
            final priorityColors = {
              'urgent': AppTheme.menstrual, 'high': AppTheme.ovulation,
              'medium': AppTheme.primary, 'low': AppTheme.follicular,
            };
            return GestureDetector(
              onTap: () => onToggle(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withOpacity(0.05)
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                        color: AppTheme.border.withOpacity(0.5), width: 0.5),
                  ),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 22, height: 22, margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppTheme.primary.withOpacity(0.2)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.border,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 13, color: AppTheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['title'] ?? '', style: TextStyle(
                          color: selected ? AppTheme.textPrimary : AppTheme.textSub,
                          fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (priorityColors[t['priority']] ?? AppTheme.primary)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(t['priority'] ?? 'medium', style: TextStyle(
                              color: priorityColors[t['priority']] ?? AppTheme.primary,
                              fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        if (t['suggested_due_date'] != null) ...[
                          const SizedBox(width: 8),
                          Text(t['suggested_due_date'],
                              style: const TextStyle(
                                  color: AppTheme.textSub, fontSize: 11)),
                        ],
                      ]),
                      if (t['phase_rationale'] != null) ...[
                        const SizedBox(height: 4),
                        Text('💡 ${t['phase_rationale']}',
                            style: TextStyle(
                                color: AppTheme.textSub.withOpacity(0.7),
                                fontSize: 11, height: 1.3)),
                      ],
                    ],
                  )),
                ]),
              ),
            );
          }),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: loading ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSub,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: loading ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: loading
                      ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text('Add ${approvedIndices.length} task${approvedIndices.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}