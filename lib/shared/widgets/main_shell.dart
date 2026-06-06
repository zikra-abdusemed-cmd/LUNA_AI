import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/route_names.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go(RouteNames.dashboard);
            case 1: context.go(RouteNames.chat);
            case 2: context.go(RouteNames.taskBoard);
            case 3: context.go(RouteNames.wellnessTwin);
            case 4: context.go(RouteNames.profile);
          }
        },
        selectedIndex: _selectedIndex(context),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble), label: 'Luna'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline),
              selectedIcon: Icon(Icons.check_circle), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights), label: 'Wellness'),
          NavigationDestination(icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(RouteNames.dashboard)) return 0;
    if (location.startsWith(RouteNames.chat)) return 1;
    if (location.startsWith(RouteNames.taskBoard)) return 2;
    if (location.startsWith(RouteNames.wellnessTwin)) return 3;
    if (location.startsWith(RouteNames.profile)) return 4;
    return 0;
  }
}