import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/supabase_provider.dart';

final tasksStreamProvider = StreamProvider((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return const Stream.empty();

  return supabase
      .from('tasks')
      .stream(primaryKey: ['id'])
      .map((rows) {
        final userRows = rows
            .where((r) =>
                r['user_id'] == user.id && r['status'] != 'cancelled')
            .toList();
        userRows.sort((a, b) {
          final aDate = a['due_date'] as String? ?? '';
          final bDate = b['due_date'] as String? ?? '';
          return aDate.compareTo(bDate);
        });
        return userRows;
      });
});

class TaskNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  TaskNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> updateStatus(String taskId, String newStatus) async {
    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('tasks')
        .update({
          'status': newStatus,
          if (newStatus == 'completed')
            'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', taskId);
  }

  Future<void> deleteTask(String taskId) async {
    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('tasks')
        .update({'status': 'cancelled'})
        .eq('id', taskId);
  }
}

final taskNotifierProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<void>>((ref) {
  return TaskNotifier(ref);
});
