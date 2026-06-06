import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Supabase.initialize(
    url: 'https://zwysjndgjqtozyzpxgwn.supabase.co',
    anonKey: 'sb_secret_4xR1HLtvuhpmdHbd1DYGvw_njBpB-uw',
  );

  runApp(const ProviderScope(child: LunaApp()));
}