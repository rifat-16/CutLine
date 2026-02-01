import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/owner/providers/salon_setup_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class BarberCreationResult {
  final BarberInput input;
  final String? uid;
  final String? error;

  const BarberCreationResult({
    required this.input,
    this.uid,
    this.error,
  });

  bool get isSuccess => uid != null && error == null;
}

class BarberService {
  BarberService({
    FirebaseAuth? secondaryAuth,
    FirebaseFirestore? secondaryFirestore,
  })  : _secondaryAuth = secondaryAuth,
        _secondaryFirestore = secondaryFirestore;

  FirebaseAuth? _secondaryAuth;
  FirebaseFirestore? _secondaryFirestore;
  FirebaseApp? _secondaryApp;

  Future<void> _ensureSecondaryApp() async {
    if (_secondaryApp != null) return;
    try {
      _secondaryApp = Firebase.app('barberCreator');
    } catch (_) {
      final primaryOptions = Firebase.app().options;
      _secondaryApp = await Firebase.initializeApp(
        name: 'barberCreator',
        options: primaryOptions,
      );
    }
    _secondaryAuth ??= FirebaseAuth.instanceFor(app: _secondaryApp!);
    _secondaryFirestore ??= FirebaseFirestore.instanceFor(app: _secondaryApp!);
  }

  Future<List<BarberCreationResult>> createBarbers({
    required String ownerId,
    required List<BarberInput> barbers,
  }) async {
    if (barbers.isEmpty) return [];
    await _ensureSecondaryApp();

    final results = <BarberCreationResult>[];

    for (final barber in barbers) {
      try {
        final credential = await _secondaryAuth!.createUserWithEmailAndPassword(
            email: barber.email.trim(), password: barber.password);
        final uid = credential.user?.uid;
        if (uid != null) {
          await credential.user?.updateDisplayName(barber.name.trim());
          await _secondaryFirestore!.collection('users').doc(uid).set({
            'uid': uid,
            'email': barber.email.trim(),
            'name': barber.name.trim(),
            'specialization': barber.specialization.trim(),
            'phone': barber.phone.trim(),
            'role': 'barber',
            'ownerId': ownerId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          results.add(BarberCreationResult(input: barber, uid: uid));
        } else {
          results.add(BarberCreationResult(
            input: barber,
            error: 'Could not create account for ${barber.email}',
          ));
        }
      } on FirebaseAuthException catch (e) {
        results.add(BarberCreationResult(
          input: barber,
          error: _mapAuthError(e),
        ));
      } catch (_) {
        results.add(BarberCreationResult(
          input: barber,
          error: 'Could not create account for ${barber.email}',
        ));
      }
    }

    // keep secondary auth clean
    await _secondaryAuth?.signOut();
    return results;
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email already in use.';
      case 'invalid-email':
        return 'Invalid email.';
      case 'weak-password':
        return 'Password too weak.';
      default:
        return e.message ?? 'Could not create account.';
    }
  }
}
