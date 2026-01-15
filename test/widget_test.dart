import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subnet_rush/main.dart';
import 'package:subnet_rush/features/auth/data/auth_repository.dart';

import 'package:firebase_auth/firebase_auth.dart';


// Since we don't have mockito generated classes yet, we will just override with a simple fake stream
// or just test the LoginScreen directly with overridden providers.

class FakeAuthRepository implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => Stream.value(null); // Emit null to simulate logged out

  @override
  User? get currentUser => null;

  @override
  Future<User?> signInWithEmail(String email, String password) async => null;

  @override
  Future<User?> signUpWithEmail(String email, String password) async => null;

  @override
  Future<void> signOut() async {} 
}

void main() {
  testWidgets('Login Screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We override the authRepositoryProvider to use our Fake.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const SubnetRushApp(),
      ),
    );

    // Verify that we are on the Login Screen (since Fake emits null user)
    // "SubnetRush" title is present
    expect(find.text('SubnetRush'), findsOneWidget);
    
    // "Login" button is present
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });
}
