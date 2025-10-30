import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isAuthenticated => _currentUser != null;
  bool get isOwner => _currentUser?.role == UserRole.owner;
  bool get isBarber => _currentUser?.role == UserRole.barber;
  bool get isRegularUser => _currentUser?.role == UserRole.user;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        await loadUserData(firebaseUser.uid);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> loadUserData(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = await _firestoreService.getUser(userId);
      if (user != null) {
        _currentUser = user;
        
        // Get and update FCM token
        final fcmToken = await _notificationService.getFCMToken();
        if (fcmToken != null && user.fcmToken != fcmToken) {
          await _firestoreService.updateUser(userId, {'fcmToken': fcmToken});
          _currentUser = user.copyWith(fcmToken: fcmToken);
        }
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = await _authService.signInWithEmailAndPassword(email, password);
      
      if (user != null) {
        await loadUserData(user.uid);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = await _authService.signUpWithEmailAndPassword(email, password);
      
      if (user != null) {
        final fcmToken = await _notificationService.getFCMToken();
        
        final userModel = UserModel(
          id: user.uid,
          name: name,
          phone: phone,
          role: role,
          createdAt: DateTime.now(),
          fcmToken: fcmToken,
        );

        await _firestoreService.createUser(userModel);
        _currentUser = userModel;
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signOut();
      _currentUser = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
  }) async {
    try {
      if (_currentUser == null) return;

      _isLoading = true;
      _error = null;
      notifyListeners();

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;

      await _firestoreService.updateUser(_currentUser!.id, updates);
      _currentUser = _currentUser!.copyWith(
        name: name ?? _currentUser!.name,
        phone: phone ?? _currentUser!.phone,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
