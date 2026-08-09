import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/network/http_service.dart';

import 'features/auth/controller/auth_controller.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/services/auth_storage_service.dart';
import 'features/auth/ui/login_page.dart';

import 'features/route/controller/route_controller.dart';
import 'features/route/repositories/route_repository.dart';
import 'features/route/ui/route_page.dart';

// ---------------- CORE ----------------

final httpServiceProvider = Provider<HttpService>((ref) {
  return HttpService(AppConfig.baseUrl);
});

// ---------------- AUTH ----------------

final authStorageProvider = Provider<AuthStorageService>((ref) {
  return AuthStorageService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(httpServiceProvider));
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

// ---------------- ROUTE ----------------

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository(ref.read(httpServiceProvider));
});

final routeControllerProvider =
NotifierProvider<RouteController, RouteControllerState>(
  RouteController.new,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      themeMode: ThemeMode.dark,

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,

        scaffoldBackgroundColor:
        const Color(0xFF0B1220),

        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade400,
          secondary: Colors.blue.shade300,
          surface: const Color(0xFF111827),
        ),

        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        inputDecorationTheme:
        InputDecorationTheme(
          filled: true,
          fillColor:
          const Color(0xFF1F2937),

          border: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(14),
          ),
        ),
      ),

      home: const AuthGate(),
    );
  }
}

/// Shows the login screen until a worker session exists, then shows
/// today's route. This is the only place that switches between the two
/// -- RoutePage and LoginPage don't need to know about each other.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    switch (authState.status) {
      case AuthStatus.checking:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case AuthStatus.loggedIn:
        return const RoutePage();

      case AuthStatus.loggedOut:
      case AuthStatus.loading:
      case AuthStatus.error:
        return const LoginPage();
    }
  }
}
