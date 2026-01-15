import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';
import '../domain/user_profile.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // No initial state
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signInWithEmail(email, password));
  }

  Future<void> signUp({
    required String email, 
    required String password,
    required String username,
    required String name,
    required String surname,
    required int avatarId,
  }) async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      // 1. Check Username
      final isAvailable = await ref.read(userRepositoryProvider).isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username already taken. Please choose another.');
      }
      
      // 2. Create Auth User
      final user = await ref.read(authRepositoryProvider).signUpWithEmail(email, password);
      if (user == null) throw Exception('Registered user is null');
      
      // 3. Create Firestore Profile
      final newProfile = UserProfile(
        uid: user.uid,
        email: email,
        username: username,
        name: name,
        surname: surname,
        profilePhotoBase64: null, // Placeholder or remove if unused
        joinDate: DateTime.now(),
      );
      
      await ref.read(userRepositoryProvider).createUserProfile(newProfile);
    });
  }
  
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signOut());
  }
}
