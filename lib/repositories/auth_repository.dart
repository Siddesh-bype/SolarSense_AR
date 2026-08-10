// lib/repositories/auth_repository.dart
//
// Auth boundary for SolarSense AR.
//
// The app is **on-device first**: there is no mandatory backend, and the
// default session is a guest session held in [UserSession]. This keeps the
// demo fully functional offline. The Firebase implementation below is a SEAM
// only — it is documented, not imported, so we don't pull `firebase_auth`
// into the build until a backend is actually wired.

import '../services/user_session.dart';

abstract class AuthRepository {
  /// Returns the active session, or null if no user is signed in.
  Future<UserSession?> currentUser();

  /// Establish a session. On-device this is a no-op guest session.
  Future<UserSession> signIn();

  Future<void> signOut();
}

class OnDeviceAuthRepository implements AuthRepository {
  final UserSession _session;
  const OnDeviceAuthRepository(this._session);

  @override
  Future<UserSession?> currentUser() async => _session;

  @override
  Future<UserSession> signIn() async => _session;

  @override
  Future<void> signOut() async => _session.clear();
}

/*
/// ── FIREBASE SEAM (optional) ───────────────────────────────────────────────
/// Activate by adding `firebase_core` + `firebase_auth` to pubspec.yaml and
/// initialising Firebase in main(). Then swap the repository implementation.
///
/// class FirebaseAuthRepository implements AuthRepository {
///   final FirebaseAuth _auth;
///   final UserSession _session;
///   FirebaseAuthRepository(this._auth, this._session);
///
///   @override
///   Future<UserSession?> currentUser() async {
///     final u = _auth.currentUser;
///     if (u == null) return null;
///     _session.updateProfile(name: u.displayName, email: u.email);
///     return _session;
///   }
///
///   @override
///   Future<UserSession> signIn() async {
///     // Email link / Google / phone — your choice. Returns a guest-equivalent
///     // session plus the Firebase UID for linking scans & leads.
///     throw UnimplementedError('Wire your Firebase sign-in provider here.');
///   }
///
///   @override
///   Future<void> signOut() async {
///     await _auth.signOut();
///     _session.clear();
///   }
/// }
*/
