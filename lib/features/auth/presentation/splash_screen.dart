import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('onboarding_completed')
          .eq('id', session.user.id)
          .single();
      if (mounted) {
        if (profile['onboarding_completed'] == true) {
          context.go(RouteNames.dashboard);
        } else {
          context.go(RouteNames.onboarding);
        }
      }
    } else {
      if (mounted) context.go(RouteNames.login);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.primary.withOpacity(0.3),
                  AppTheme.primaryDeep.withOpacity(0.1),
                ]),
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: const Center(
                child: Text('🌙', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Luna', style: TextStyle(
              fontSize: 40, fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: -1,
            )),
            const SizedBox(height: 8),
            Text('Your Wellness Copilot', style: TextStyle(
              fontSize: 16, color: AppTheme.textSub,
              letterSpacing: 1,
            )),
            const SizedBox(height: 60),
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary.withOpacity(0.5),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}