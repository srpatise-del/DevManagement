import 'package:flutter_test/flutter_test.dart';
import 'package:devcase_test/providers/app_state.dart';
import 'package:devcase_test/models/app_models.dart';

void main() {
  group('Supabase Profile Mapping & Team Tests', () {
    test('loginWithSupabaseProfile correctly sets authUserId and employeeCode id', () {
      final appState = AppState();
      
      final profile = {
        'id': 'uuid-1234-5678',
        'employee_code': 'EMP-999',
        'full_name': 'Supabase User',
        'email': 'supabase@company.com',
        'role': 'Developer',
        'team_status': 'pending',
        'teams': {'code': 'mobile', 'name': 'Mobile Team'},
      };

      appState.loginWithSupabaseProfile(profile);

      expect(appState.currentUser.id, 'EMP-999');
      expect(appState.currentUser.authUserId, 'uuid-1234-5678');
      expect(appState.currentUser.name, 'Supabase User');
      expect(appState.currentUser.email, 'supabase@company.com');
      // Team should be parsed from profile['teams'] even though team_status is 'pending'
      expect(appState.currentUser.team, TeamType.mobile);
    });

    test('Phase 1: Real Data Mode sets real mode and empty case/order lists', () {
      final appState = AppState();
      final profile = {
        'id': 'uuid-real-user',
        'employee_code': 'EMP-001',
        'full_name': 'Real User',
        'email': 'real@company.com',
        'role': 'Developer',
        'team_status': 'approved',
      };

      appState.loginWithSupabaseProfile(profile);

      expect(appState.dataMode, AppDataMode.real);
      expect(appState.isLoggedIn, true);
      expect(appState.cases, isEmpty);
      expect(appState.orders, isEmpty);
    });

    test('Phase 1: Demo Mode sets demo mode and populates mock data', () {
      final appState = AppState();
      final demoUser = appState.registeredUsers.first;

      appState.quickDemoLogin(demoUser);

      expect(appState.dataMode, AppDataMode.demo);
      expect(appState.isLoggedIn, true);
      expect(appState.cases, isNotEmpty);
      expect(appState.orders, isNotEmpty);
    });
  });
}

