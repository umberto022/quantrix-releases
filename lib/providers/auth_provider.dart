import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final QuantrixUser? user;
  final String? error;

  const AuthState({required this.status, this.user, this.error});

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  AuthNotifier() : super(const AuthState(status: AuthStatus.loading)) {
    _auth.authStateChanges().listen((user) async {
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        final profile = await _fetchProfile(user.uid);
        state = AuthState(status: AuthStatus.authenticated, user: profile);
      }
    });
  }

  Future<QuantrixUser> _fetchProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return QuantrixUser.fromJson({...doc.data()!, 'id': uid});
    }
    final user = _auth.currentUser!;
    return QuantrixUser(
      id: uid,
      name: user.displayName ?? user.email!.split('@')[0],
      email: user.email!,
      createdAt: DateTime.now(),
    );
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.updateDisplayName(name.trim());

      final user = QuantrixUser(
        id: cred.user!.uid,
        name: name.trim(),
        email: email.trim().toLowerCase(),
        createdAt: DateTime.now(),
      );

      await _db.collection('users').doc(cred.user!.uid).set(user.toJson());
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return null;
    } on FirebaseAuthException catch (e) {
      final msg = _mapError(e.code);
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return msg;
    }
  }

  Future<String?> login({required String email, required String password}) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      final msg = _mapError(e.code);
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return msg;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este email ya está registrado';
      case 'invalid-email':
        return 'Email inválido';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres)';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o contraseña incorrectos';
      case 'too-many-requests':
        return 'Demasiados intentos. Intentá más tarde';
      case 'network-request-failed':
        return 'Sin conexión a internet';
      default:
        return 'Error inesperado. Intentá de nuevo';
    }
  }
}
