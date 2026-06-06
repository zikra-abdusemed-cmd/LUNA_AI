import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/ai_chat/presentation/chat_screen.dart';
import '../../features/tasks/presentation/task_board_screen.dart';
import '../../features/tasks/presentation/suggestion_review_screen.dart';
import '../../features/wellness_twin/presentation/wellness_twin_screen.dart';
import '../../features/predictions/presentation/predictions_screen.dart';
import '../../features/mood_tracking/presentation/mood_log_screen.dart';
import '../../features/cycle_tracking/presentation/cycle_calendar_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../shared/widgets/main_shell.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.splash,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loc = state.matchedLocation;
      const publicRoutes = {
        RouteNames.splash,
        RouteNames.login,
        RouteNames.onboarding,
      };
      if (session == null && !publicRoutes.contains(loc)) {
        return RouteNames.login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (c, s) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (c, s) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (c, s) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.moodLog,
        builder: (c, s) => const MoodLogScreen(),
      ),
      GoRoute(
        path: RouteNames.cycleCalendar,
        builder: (c, s) => const CycleCalendarScreen(),
      ),
      GoRoute(
        path: RouteNames.predictions,
        builder: (c, s) => const PredictionsScreen(),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (c, s) => const SettingsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.dashboard,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: RouteNames.chat,
            pageBuilder: (c, s) => const NoTransitionPage(child: ChatScreen()),
          ),
          GoRoute(
            path: RouteNames.taskBoard,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: TaskBoardScreen()),
            routes: [
              GoRoute(
                path: 'suggestions',
                builder: (c, s) => const SuggestionReviewScreen(),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.wellnessTwin,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: WellnessTwinScreen()),
          ),
          GoRoute(
            path: RouteNames.profile,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
    ],
  );
});
