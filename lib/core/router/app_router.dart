import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/business/presentation/screens/business_shell_screen.dart';
import '../../features/business/presentation/screens/organization_info_screen.dart';
import '../../features/business/presentation/screens/organization_request_screen.dart';
import '../../features/home/presentation/screens/main_shell_screen.dart';
import '../../features/home/presentation/screens/placeholder_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/organizations/presentation/screens/organizations_screen.dart';
import '../../features/tasks/presentation/screens/add_task_screen.dart';

class AppRouter {
  static GoRouter create(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (context, state) {
        final status = auth.status;
        final loc = state.matchedLocation;

        if (status == AuthStatus.unknown) {
          return loc == '/' ? null : '/';
        }

        final isAuthRoute =
            loc == '/login' ||
            loc == '/register' ||
            loc == '/organization-request' ||
            loc == '/forgot-password' ||
            loc.startsWith('/reset-password');

        if (status == AuthStatus.authenticated) {
          if (loc == '/' || isAuthRoute) return '/home';
          return null;
        }

        // unauthenticated — restrict protected routes
        final protected =
            loc == '/home' ||
            loc == '/planner' ||
            loc == '/map' ||
            loc == '/reports' ||
            loc == '/profile' ||
            loc == '/organizations' ||
            loc == '/tasks/add';
        if (protected) return '/login';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(
          path: '/organization-request',
          builder: (_, __) => const OrganizationRequestScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (_, state) =>
              ResetPasswordScreen(token: state.uri.queryParameters['token']),
        ),
        GoRoute(path: '/home', builder: (_, __) => const MainShellScreen()),
        GoRoute(
          path: '/business',
          builder: (_, __) => const BusinessShellScreen(),
        ),
        GoRoute(
          path: '/business/info',
          builder: (_, __) => const OrganizationInfoScreen(),
        ),
        GoRoute(path: '/tasks/add', builder: (_, __) => const AddTaskScreen()),
        GoRoute(
          path: '/planner',
          builder: (_, __) => const PlaceholderScreen(
            title: 'Төлөвлөгөө',
            message: 'Ажлын төлөвлөгөө модуль удахгүй нэмэгдэнэ.',
            icon: Icons.checklist_rtl,
          ),
        ),
        GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
        GoRoute(
          path: '/reports',
          builder: (_, __) => const PlaceholderScreen(
            title: 'Санал, гомдол',
            message: 'Иргэний оролцооны модуль удахгүй нэмэгдэнэ.',
            icon: Icons.report_gmailerrorred,
          ),
        ),
        GoRoute(
          path: '/organizations',
          builder: (_, __) => const OrganizationsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const PlaceholderScreen(
            title: 'Профайл',
            message: 'Профайл удахгүй нэмэгдэнэ.',
            icon: Icons.person,
          ),
        ),
      ],
      errorBuilder: (_, state) => Scaffold(
        body: Center(child: Text('Хуудас олдсонгүй: ${state.error}')),
      ),
    );
  }
}

extension AuthProviderRead on BuildContext {
  AuthProvider get authRead => read<AuthProvider>();
}
