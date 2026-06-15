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
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;

  AuthNotifier() : super(const AuthState(status: AuthStatus.loading)) {
    _init();
  }

  void _init() {
    try {
      _auth = FirebaseAuth.instance;
      _db = FirebaseFirestore.instance;
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      _auth!.authStateChanges().listen((user) async {
        try {
          if (user == null) {
            state = const AuthState(status: AuthStatus.unauthenticated);
          } else {
            final profile = await _fetchProfile(user.uid);
            state = AuthState(status: AuthStatus.authenticated, user: profile);
          }
        } catch (_) {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      }, onError: (_) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      });
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<QuantrixUser> _fetchProfile(String uid) async {
    final doc = await _db!.collection('users').doc(uid).get();
    if (doc.exists) {
      return QuantrixUser.fromJson({...doc.data()!, 'id': uid});
    }
    final user = _auth!.currentUser!;
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
    if (_auth == null || _db == null) {
      return 'Firebase no disponible. Verificá tu conexión e intentá de nuevo.';
    }
    state = const AuthState(status: AuthStatus.loading);
    try {
      final cred = await _auth!.createUserWithEmailAndPassword(
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

      await _db!.collection('users').doc(cred.user!.uid).set(user.toJson());
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return null;
    } on FirebaseAuthException catch (e) {
      final msg = _mapError(e.code);
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return msg;
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated, error: 'Error inesperado');
      return 'Error inesperado. Intentá de nuevo';
    }
  }

  Future<String?> login({required String email, required String password}) async {
    if (_auth == null) {
      return 'Firebase no disponible. Verificá tu conexión e intentá de nuevo.';
    }
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      final msg = _mapError(e.code);
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return msg;
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return 'Error inesperado. Intentá de nuevo';
    }
  }

  Future<void> logout() async {
    try {
      await _auth?.signOut();
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    if (_auth == null) return 'Firebase no disponible';
    try {
      await _auth!.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (_) {
      return 'Error inesperado. Intentá de nuevo';
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
