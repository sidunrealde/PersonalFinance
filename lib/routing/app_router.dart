import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isAuthenticated && !isAuthRoute) {
        return '/auth/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/login',
        builder:
            (context, state) => const Scaffold(
              body: Center(child: Text('Login — coming in Plan 05')),
            ),
      ),
      GoRoute(
        path: '/auth/signup',
        builder:
            (context, state) => const Scaffold(
              body: Center(child: Text('Sign Up — coming in Plan 05')),
            ),
      ),
      GoRoute(
        path: '/onboarding',
        builder:
            (context, state) => const Scaffold(
              body: Center(child: Text('Onboarding — coming in Plan 05')),
            ),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return Scaffold(
            body: Center(child: Text('Invite: $token — coming in Plan 05')),
          );
        },
      ),
      GoRoute(
        path: '/',
        builder:
            (context, state) =>
                const Scaffold(body: Center(child: Text('Dashboard'))),
      ),
    ],
  );
});
