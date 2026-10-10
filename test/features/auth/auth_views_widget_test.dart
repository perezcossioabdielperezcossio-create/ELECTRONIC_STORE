import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:electronic_store/features/auth/data/models/user_model.dart';
import 'package:electronic_store/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:electronic_store/features/auth/presentation/views/login_view.dart';
import 'package:electronic_store/features/auth/presentation/views/register_seller_view.dart';
import 'package:electronic_store/features/auth/presentation/widgets/admin_approval_dialog.dart';

class MockAuthViewModel extends Mock with ChangeNotifier implements AuthViewModel {}

void main() {
  late MockAuthViewModel mockAuthVM;

  setUp(() {
    mockAuthVM = MockAuthViewModel();
    when(() => mockAuthVM.isLoading).thenReturn(false);
    when(() => mockAuthVM.errorMessage).thenReturn(null);
    when(() => mockAuthVM.isAuthenticated).thenReturn(false);
    when(() => mockAuthVM.isAdmin).thenReturn(false);
    when(() => mockAuthVM.isSeller).thenReturn(false);
    when(() => mockAuthVM.currentUser).thenReturn(null);
    when(() => mockAuthVM.isInitialized).thenReturn(true);
  });

  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider<AuthViewModel>.value(
      value: mockAuthVM,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('LoginView Widget Tests', () {
    testWidgets('renders brand title, inputs and buttons', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const LoginView()));
      await tester.pumpAndSettle();

      expect(find.text('ElectronicStore'), findsOneWidget);
      expect(find.text('Número de Celular'), findsOneWidget);
      expect(find.text('PIN de 6 dígitos'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
      expect(find.text('Registrarse como Vendedor'), findsOneWidget);
    });

    testWidgets('validates required fields on Ingresar click', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const LoginView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu número de celular'), findsOneWidget);
    });

    testWidgets('calls authViewModel.login when fields are valid', (tester) async {
      when(() => mockAuthVM.login(celular: '67606367', pin: '696910'))
          .thenAnswer((_) async => true);
      when(() => mockAuthVM.currentUser).thenReturn(UserModel.masterAdmin1);

      await tester.pumpWidget(buildTestableWidget(const LoginView()));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Número de Celular'), '67606367');
      await tester.enterText(find.widgetWithText(TextFormField, 'PIN de 6 dígitos'), '696910');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      verify(() => mockAuthVM.login(celular: '67606367', pin: '696910')).called(1);
    });
  });

  group('AdminApprovalDialog Widget Tests', () {
    testWidgets('renders dialog and validates admin pin', (tester) async {
      String? returnedPin;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  returnedPin = await showDialog<String>(
                    context: ctx,
                    builder: (_) => const AdminApprovalDialog(),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Autorización Admin'), findsOneWidget);
      expect(find.text('PIN del Administrador para autorizar'), findsOneWidget);

      // Enter invalid pin
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(find.text('PIN de Administrador inválido. Registro rechazado'), findsOneWidget);
      expect(returnedPin, isNull);

      // Enter valid admin pin for Abdiel
      await tester.enterText(find.byType(TextField), '696910');
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(returnedPin, '696910');
    });
  });

  group('RegisterSellerView Widget Tests', () {
    testWidgets('renders form fields for seller registration', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const RegisterSellerView()));
      await tester.pumpAndSettle();

      expect(find.text('Registro de Vendedor'), findsOneWidget);
      expect(find.text('Nombre y Apellido del Vendedor'), findsOneWidget);
      expect(find.text('Número de Celular'), findsOneWidget);
      expect(find.text('Nombre de la Tienda / Sucursal'), findsOneWidget);
      expect(find.text('PIN Personal (6 dígitos)'), findsOneWidget);
      expect(find.text('Confirmar PIN'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Registrar Vendedor'), findsOneWidget);
    });
  });
}
