import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:electronic_store/core/errors/failures.dart';
import 'package:electronic_store/features/auth/domain/entities/user.dart';
import 'package:electronic_store/features/auth/data/models/user_model.dart';
import 'package:electronic_store/features/auth/domain/repositories/auth_repository.dart';
import 'package:electronic_store/features/auth/domain/usecases/login_usecase.dart';
import 'package:electronic_store/features/auth/domain/usecases/register_seller_usecase.dart';
import 'package:electronic_store/features/auth/domain/usecases/get_current_session_usecase.dart';
import 'package:electronic_store/features/auth/domain/usecases/logout_usecase.dart';
import 'package:electronic_store/features/auth/domain/usecases/seed_master_admins_usecase.dart';
import 'package:electronic_store/features/auth/presentation/viewmodels/auth_viewmodel.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late AuthViewModel viewModel;

  setUpAll(() {
    registerFallbackValue(UserModel.masterAdmin1);
  });

  setUp(() {
    mockRepo = MockAuthRepository();
    viewModel = AuthViewModel(
      loginUseCase: LoginUseCase(mockRepo),
      registerSellerUseCase: RegisterSellerUseCase(mockRepo),
      getCurrentSessionUseCase: GetCurrentSessionUseCase(mockRepo),
      logoutUseCase: LogoutUseCase(mockRepo),
      seedMasterAdminsUseCase: SeedMasterAdminsUseCase(mockRepo),
    );
  });

  group('AuthViewModel', () {
    test('initial state is unauthenticated', () {
      expect(viewModel.isAuthenticated, false);
      expect(viewModel.currentUser, isNull);
      expect(viewModel.isAdmin, false);
      expect(viewModel.isSeller, false);
    });

    test('initSession seeds admins and loads saved session', () async {
      when(() => mockRepo.seedMasterAdmins()).thenAnswer((_) async {});
      when(() => mockRepo.getSavedSession()).thenAnswer((_) async => UserModel.masterAdmin1);

      await viewModel.initSession();

      expect(viewModel.isAuthenticated, true);
      expect(viewModel.currentUser, UserModel.masterAdmin1);
      expect(viewModel.isAdmin, true);
      expect(viewModel.isInitialized, true);
    });

    test('login success sets currentUser and state', () async {
      when(() => mockRepo.login(celular: '67606367', pin: '696910'))
          .thenAnswer((_) async => const Right(UserModel.masterAdmin1));

      final result = await viewModel.login(celular: '67606367', pin: '696910');

      expect(result, true);
      expect(viewModel.isAuthenticated, true);
      expect(viewModel.isAdmin, true);
      expect(viewModel.errorMessage, isNull);
    });

    test('login failure sets error message', () async {
      when(() => mockRepo.login(celular: '67606367', pin: '111111'))
          .thenAnswer((_) async => const Left(AuthFailure('PIN incorrecto.')));

      final result = await viewModel.login(celular: '67606367', pin: '111111');

      expect(result, false);
      expect(viewModel.isAuthenticated, false);
      expect(viewModel.errorMessage, 'PIN incorrecto.');
    });

    test('registerSeller calls repo and returns status', () async {
      const seller = UserModel(
        celular: '77665544',
        nombre: 'Vendedor Test',
        pin: '123456',
        role: UserRole.seller,
        tiendaNombre: 'Sucursal 1',
        activo: true,
      );

      when(() => mockRepo.registerSeller(user: any(named: 'user'), adminPin: '696910'))
          .thenAnswer((_) async => const Right(seller));

      final result = await viewModel.registerSeller(
        nombre: 'Vendedor Test',
        celular: '77665544',
        tiendaNombre: 'Sucursal 1',
        pin: '123456',
        adminPin: '696910',
      );

      expect(result, true);
      expect(viewModel.errorMessage, isNull);
    });

    test('logout clears user state and persisted session', () async {
      when(() => mockRepo.login(celular: '67606367', pin: '696910'))
          .thenAnswer((_) async => const Right(UserModel.masterAdmin1));
      when(() => mockRepo.clearSession()).thenAnswer((_) async {});

      await viewModel.login(celular: '67606367', pin: '696910');
      expect(viewModel.isAuthenticated, true);

      await viewModel.logout();
      expect(viewModel.isAuthenticated, false);
      expect(viewModel.currentUser, isNull);
    });
  });
}
