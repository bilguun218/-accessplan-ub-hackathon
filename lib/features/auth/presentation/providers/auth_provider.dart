import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/auth_response_model.dart';
import '../../data/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;

  AuthProvider(this._repo);

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  AuthStatus _status = AuthStatus.unknown;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> checkAuth() async {
    _setLoading(true);
    try {
      final user = await _repo.tryAutoLogin();
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    _setError(null);
    _setLoading(true);
    try {
      final res = await _repo.login(LoginRequest(email: email, password: password));
      _user = res.user;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Сервертэй холбогдоход алдаа гарлаа.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(RegisterRequest request) async {
    _setError(null);
    _setLoading(true);
    try {
      final res = await _repo.register(request);
      _user = res.user;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Сервертэй холбогдоход алдаа гарлаа.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> forgotPassword(String email) async {
    _setError(null);
    _setLoading(true);
    try {
      await _repo.forgotPassword(email);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _setError(null);
    _setLoading(true);
    try {
      await _repo.resetPassword(token, newPassword);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _repo.logout();
    } finally {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
    }
  }

  Future<void> handleSessionExpired() async {
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
