import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/push_service.dart';
import 'core/settings.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_screen.dart';
import 'features/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load config from the bundled .env asset (API_BASE_URL, ...).
  await dotenv.load(fileName: '.env');
  await Storage.init();
  // Firebase + local-notification channel (with custom sound) and the
  // background message handler. Best-effort — no-op if Firebase isn't set up.
  await PushService.initEarly();
  runApp(const ProviderScope(child: HRApp()));
}

class HRApp extends ConsumerWidget {
  const HRApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'HR App',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: mode,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kBrand)),
      );
    }
    return auth.user == null ? const AuthScreen() : const MainShell();
  }
}
