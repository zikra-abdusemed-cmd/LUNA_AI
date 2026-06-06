import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_provider.dart';

final userProfileProvider = StreamProvider((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return const Stream.empty();

  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((rows) => rows.isNotEmpty ? rows.first : null);
});