import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const DevCaseApp());
}

class DevCaseApp extends StatelessWidget {
  const DevCaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'DevCase - Case Management System',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: appState.isLoggedIn
                ? const MainNavigationScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
