import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/network/http_service.dart';

import 'features/tracking/controller/location_controller.dart';
import 'features/tracking/repositories/location_repository_impl.dart';
import 'features/tracking/services/local_storage_service.dart';
import 'features/tracking/ui/location_sharing_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  final httpService =
  HttpService(AppConfig.baseUrl);

  final locationRepo =
  LocationRepositoryImpl(httpService);

  final storage = LocalStorageService();

  runApp(
    ProviderScope(
      overrides: [
        locationControllerProvider.overrideWith(
              (ref) =>
              LocationController(locationRepo, storage),
        ),
      ],
      child: const MyApp(),
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

      home: const LocationSharingPage(),
    );
  }
}