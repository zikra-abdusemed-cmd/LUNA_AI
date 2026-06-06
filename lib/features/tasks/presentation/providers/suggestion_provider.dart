import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/supabase_provider.dart';

final pendingSuggestionsProvider = StreamProvider((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return const Stream.empty();

  return supabase
      .from('task_suggestions')
      .stream(primaryKey: ['id'])
      .map((rows) {
        final pending = rows
            .where((r) =>
                r['user_id'] == user.id && r['status'] == 'pending')
            .toList();
        pending.sort((a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String));
        return pending;
      });
});

final pendingSuggestionsCountProvider = Provider<int>((ref) {
  return ref.watch(pendingSuggestionsProvider).when(
        data: (suggestions) => suggestions.length,
        loading: () => 0,
        error: (_, __) => 0,
      );
});

class SuggestionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  SuggestionNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> approveSuggestion({
    required String suggestionId,
    required List<Map<String, dynamic>> selectedTasks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.functions.invoke(
        'approve_task_suggestion',
        body: {
          'suggestion_id': suggestionId,
          'selected_tasks': selectedTasks,
        },
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rejectSuggestion(String suggestionId) async {
    final supabase = ref.read(supabaseProvider);
    await supabase
        .from('task_suggestions')
        .update({'status': 'rejected'})
        .eq('id', suggestionId);
  }
}

final suggestionNotifierProvider =
    StateNotifierProvider<SuggestionNotifier, AsyncValue<void>>((ref) {
  return SuggestionNotifier(ref);
});
