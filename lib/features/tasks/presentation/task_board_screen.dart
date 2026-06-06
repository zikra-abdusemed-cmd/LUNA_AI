import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/supabase_provider.dart';
import './providers/suggestion_provider.dart';

class TaskBoardScreen extends ConsumerWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sb   = ref.watch(supabaseProvider);
    final user = sb.auth.currentUser;
    final pendingCount = ref.watch(pendingSuggestionsCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: const Text('Tasks', style: TextStyle(
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        actions: [
          if (pendingCount > 0)
            GestureDetector(
              onTap: () => context.go(RouteNames.suggestions),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 14),
                  const SizedBox(width: 4),
                  Text('$pendingCount suggestions',
                      style: const TextStyle(color: AppTheme.accent,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : FutureBuilder<List<Map<String, dynamic>>>(
        future: sb.from('tasks')
            .select()
            .eq('user_id', user.id)
            .neq('status', 'cancelled')
            .order('due_date') as Future<List<Map<String, dynamic>>>,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final tasks = snap.data ?? [];
          if (tasks.isEmpty) return _EmptyTaskState();
          return _TaskList(tasks: tasks, ref: ref);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(RouteNames.chat),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        child: const Icon(Icons.auto_awesome),
        tooltip: 'Ask Luna to plan tasks',
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final WidgetRef ref;
  const _TaskList({required this.tasks, required this.ref});

  @override
  Widget build(BuildContext context) {
    final pending   = tasks.where((t) => t['status'] == 'pending').toList();
    final inProgress= tasks.where((t) => t['status'] == 'in_progress').toList();
    final overdue   = tasks.where((t) => t['status'] == 'overdue').toList();
    final done      = tasks.where((t) => t['status'] == 'completed').toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (overdue.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(title: 'Overdue', color: AppTheme.menstrual,
              count: overdue.length),
          ...overdue.map((t) => TaskCard(task: t, ref: ref)),
        ],
        if (inProgress.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(title: 'In Progress', color: AppTheme.follicular,
              count: inProgress.length),
          ...inProgress.map((t) => TaskCard(task: t, ref: ref)),
        ],
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(title: 'Pending', color: AppTheme.primary,
              count: pending.length),
          ...pending.map((t) => TaskCard(task: t, ref: ref)),
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(title: 'Completed', color: AppTheme.textSub,
              count: done.length),
          ...done.map((t) => TaskCard(task: t, ref: ref)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final int count;
  const _SectionHeader({required this.title, required this.color, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      Text(title, style: TextStyle(color: color,
          fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(width: 6),
      Text('($count)', style: TextStyle(color: color.withOpacity(0.6), fontSize: 12)),
    ]),
  );
}

class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final WidgetRef ref;
  const TaskCard({required this.task, required this.ref});

  @override
  Widget build(BuildContext context) {
    final priority = task['priority'] as String? ?? 'medium';
    final status   = task['status'] as String? ?? 'pending';
    final dueDate  = task['due_date'] != null
        ? DateTime.tryParse(task['due_date']) : null;
    final isAI     = task['is_ai_generated'] == true;
    final isDone   = status == 'completed';
    final colors = {
      'urgent': AppTheme.menstrual,
      'high': AppTheme.ovulation,
      'medium': AppTheme.primary,
      'low': AppTheme.follicular,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? AppTheme.border.withOpacity(0.3) : AppTheme.border,
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: GestureDetector(
          onTap: () => _toggleStatus(context),
          child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone ? AppTheme.follicular : AppTheme.border,
                width: 2,
              ),
              color: isDone ? AppTheme.follicular.withOpacity(0.2) : Colors.transparent,
            ),
            child: isDone
                ? const Icon(Icons.check, size: 14, color: AppTheme.follicular)
                : null,
          ),
        ),
        title: Text(
          task['title'] ?? '',
          style: TextStyle(
            color: isDone ? AppTheme.textSub : AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(children: [
          Container(
            margin: const EdgeInsets.only(right: 6, top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (colors[priority] ?? AppTheme.primary).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(priority,
                style: TextStyle(color: colors[priority] ?? AppTheme.primary,
                    fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          if (dueDate != null)
            Text(DateFormat('MMM d').format(dueDate),
                style: const TextStyle(color: AppTheme.textSub, fontSize: 11)),
          if (isAI)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.auto_awesome, color: AppTheme.primary, size: 11),
            ),
        ]),
        trailing: PopupMenuButton<String>(
          color: AppTheme.bgCardLight,
          icon: const Icon(Icons.more_vert, color: AppTheme.textSub, size: 18),
          onSelected: (val) async {
            final sb = ref.read(supabaseProvider);
            await sb.from('tasks').update({'status': val}).eq('id', task['id']);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'pending',     child: Text('Mark Pending')),
            const PopupMenuItem(value: 'in_progress', child: Text('In Progress')),
            const PopupMenuItem(value: 'completed',   child: Text('Complete')),
            const PopupMenuItem(value: 'cancelled',   child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context) async {
    final sb     = ref.read(supabaseProvider);
    final status = task['status'] as String? ?? 'pending';
    final newStatus = status == 'completed' ? 'pending' : 'completed';
    await sb.from('tasks').update({'status': newStatus}).eq('id', task['id']);
  }
}

class _EmptyTaskState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('✨', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      const Text('No tasks yet', style: TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
      const SizedBox(height: 8),
      const Text('Chat with Luna to create AI-powered tasks',
          style: TextStyle(color: AppTheme.textSub, fontSize: 14),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => context.go(RouteNames.chat),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Open Luna Chat'),
      ),
    ]),
  );
}