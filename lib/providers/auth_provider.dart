import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';

// Firebase Auth Service Provider
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

// Auth State
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.isAuthenticated = false,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    _checkAuthState();
  }

  // Check if user is already logged in
  Future<void> _checkAuthState() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      final userData = await _authService.getUserData(currentUser.uid);
      if (userData != null) {
        state = state.copyWith(
          isAuthenticated: true,
          user: userData,
        );
      }
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    print('🔐 AuthProvider: Starting login for $email');

    final result = await _authService.login(
      email: email,
      password: password,
    );
    print('📊 AuthProvider: Login result type: ${result.runtimeType}');
    print('📊 AuthProvider: Login result: $result');

    if (result['success']) {
      print('✅ AuthProvider: Login successful, setting user');
      final user = result['user'];
      print('👤 AuthProvider: User type: ${user.runtimeType}');
      print('👤 AuthProvider: User data: $user');
      
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
      print('✅ AuthProvider: State updated successfully');
      return true;
    } else {
      print('❌ AuthProvider: Login failed: ${result['message']}');
      state = state.copyWith(
        isLoading: false,
        error: result['message'],
      );
      return false;
    }
  }

  // Register
  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.register(
      name: name,
      email: email,
      password: password,
    );

    if (result['success']) {
      state = state.copyWith(
        isAuthenticated: true,
        user: result['user'],
        isLoading: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result['message'],
      );
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    state = AuthState();
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return AuthNotifier(authService);
});
