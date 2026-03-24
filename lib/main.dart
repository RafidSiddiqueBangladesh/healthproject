import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/pkce_async_storage.dart';
import 'providers/nutrition_provider.dart';
import 'providers/exercise_provider.dart';
import 'providers/live_tracking_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'providers/cost_analysis_provider.dart';
import 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ftpnjqzvvwprmrfewszo.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ0cG5qcXp2dndwcm1yZmV3c3pvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzMjU5NTgsImV4cCI6MjA4OTkwMTk1OH0.ozTa_C7kllOq0_t3aYsLsqNxLtGTttbV_9BR77MZZsI',
  );

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      pkceAsyncStorage: createPkceStorage(),
      detectSessionInUri: true,
    ),
  );

  runApp(const NutriCareApp());
}

class NutriCareApp extends StatelessWidget {
  const NutriCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NutritionProvider()),
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => LiveTrackingProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CostAnalysisProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'NutriCare',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.buildTheme(),
          home: const AuthScreenWrapper(),
        ),
      ),
    );
  }
}

class AuthScreenWrapper extends StatelessWidget {
  const AuthScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScreen();
  }
}