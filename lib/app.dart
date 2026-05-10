import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/services/auth_api_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/business/data/services/business_api_service.dart';
import 'features/business/presentation/providers/business_provider.dart';

class AccessPlanApp extends StatefulWidget {
  const AccessPlanApp({super.key});

  @override
  State<AccessPlanApp> createState() => _AccessPlanAppState();
}

class _AccessPlanAppState extends State<AccessPlanApp> {
  late final AuthProvider _authProvider;
  late final BusinessProvider _businessProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final storage = SecureStorageService();
    AuthProvider? providerRef;
    final apiClient = ApiClient(
      storage: storage,
      onSessionExpired: () async {
        await providerRef?.handleSessionExpired();
      },
    );
    final api = AuthApiService(apiClient);
    final repo = AuthRepositoryImpl(api: api, storage: storage);
    _authProvider = AuthProvider(repo);
    _businessProvider = BusinessProvider(
      api: BusinessApiService(apiClient),
      storage: storage,
    )..load();
    providerRef = _authProvider;
    _router = AppRouter.create(_authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<BusinessProvider>.value(
          value: _businessProvider,
        ),
      ],
      child: MaterialApp.router(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        routerConfig: _router,
      ),
    );
  }

  @override
  void dispose() {
    _authProvider.dispose();
    _businessProvider.dispose();
    super.dispose();
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme().apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
    );
  }
}
