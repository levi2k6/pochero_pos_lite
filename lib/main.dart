import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'auth_screen.dart';
import 'payments_api.dart';
import 'payments_repository.dart';
import 'pos_screen.dart';
import 'products_repository.dart';
import 'session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite ships native support for Android and iOS only. Desktop runs use
  // the FFI implementation, which must be installed before any database call.
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Restore a persisted login so the app reopens signed in.
  final session = SessionStore();
  await session.load();

  runApp(PocheroPosLiteApp(session: session));
}

class PocheroPosLiteApp extends StatelessWidget {
  const PocheroPosLiteApp({
    super.key,
    required this.session,
    this.repository,
    this.productsRepository,
    this.paymentsApi,
  });

  /// Owns the current user and backend URL; drives login vs. POS.
  final SessionStore session;

  /// Defaults to the sqflite store; tests inject an in-memory fake.
  final PaymentsRepository? repository;

  /// Defaults to the sqflite store; tests inject an in-memory fake.
  final ProductsRepository? productsRepository;

  /// Overrides the REST client; tests inject a fake. When null, one is built
  /// from the session's URL.
  final PaymentsApi? paymentsApi;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE65100),
    );

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return MaterialApp(
          title: 'Pochero POS',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
            appBarTheme: AppBarTheme(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
            ),
          ),
          home: session.isLoggedIn
              ? PosScreen(
                  repository: repository,
                  productsRepository: productsRepository,
                  paymentsApi: paymentsApi,
                  backendUrl: session.url!,
                  onLogout: () => session.logout(),
                )
              : AuthScreen(session: session),
        );
      },
    );
  }
}
