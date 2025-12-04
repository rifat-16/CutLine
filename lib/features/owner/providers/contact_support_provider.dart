import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';

class ContactSupportProvider extends ChangeNotifier {
  ContactSupportProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isSending = false;
  String? _error;

  bool get isSending => _isSending;
  String? get error => _error;

  Future<bool> sendSupportRequest({
    required String category,
    required String subject,
    required String message,
    required String contact,
  }) async {
    final user = _authProvider.currentUser;
    _setSending(true);
    _setError(null);
    try {
      await _firestore.collection('supportRequests').add({
        'ownerId': user?.uid,
        'ownerEmail': user?.email,
        'contact': contact,
        'category': category,
        'subject': subject,
        'message': message,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _setError('Could not send support request. Please try again.');
      return false;
    } finally {
      _setSending(false);
    }
  }

  void _setSending(bool value) {
    _isSending = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}
