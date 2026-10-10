import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_session_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_seller_usecase.dart';
import '../../domain/usecases/seed_master_admins_usecase.dart';

class AuthViewModel extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final RegisterSellerUseCase registerSellerUseCase;
  final GetCurrentSessionUseCase getCurrentSessionUseCase;
  final LogoutUseCase logoutUseCase;
  final SeedMasterAdminsUseCase seedMasterAdminsUseCase;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  AuthViewModel({
    required this.loginUseCase,
    required this.registerSellerUseCase,
    required this.getCurrentSessionUseCase,
    required this.logoutUseCase,
    required this.seedMasterAdminsUseCase,
  });

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isSeller => _currentUser?.isSeller ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> initSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Ensure master admins are seeded locally and in Firestore
      await seedMasterAdminsUseCase();

      // 2. Check for existing persisted session
      _currentUser = await getCurrentSessionUseCase();
    } catch (e) {
      debugPrint('Error inicializando sesión Auth: $e');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String celular,
    required String pin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await loginUseCase(celular: celular, pin: pin);

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (user) {
        _currentUser = user;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> registerSeller({
    required String nombre,
    required String celular,
    required String tiendaNombre,
    required String pin,
    required String adminPin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final newSeller = UserModel(
      celular: celular.trim(),
      nombre: nombre.trim(),
      pin: pin.trim(),
      role: UserRole.seller,
      tiendaNombre: tiendaNombre.trim(),
      activo: true,
    );

    final result = await registerSellerUseCase(
      user: newSeller,
      adminPin: adminPin,
    );

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (user) {
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await logoutUseCase();
    _currentUser = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
