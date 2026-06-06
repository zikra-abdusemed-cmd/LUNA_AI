import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'user_profile_provider.dart';
export 'current_cycle_provider.dart';

final supabaseProvider = Provider((ref) => Supabase.instance.client);

final currentUserProvider = Provider((ref) =>
    Supabase.instance.client.auth.currentUser);
