import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'payments_repository.dart';
import 'pos_screen.dart';
import 'products_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite ships native support for Android and iOS only. Desktop runs use
  // the FFI implementation, which must be installed before any database call.
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const PocheroPosLiteApp());
}

class PocheroPosLiteApp extends StatelessWidget {
  const PocheroPosLiteApp({
    super.key,
    this.repository,
    this.productsRepository,
  });

  /// Defaults to the sqflite store; tests inject an in-memory fake.
  final PaymentsRepository? repository;

  /// Defaults to the sqflite store; tests inject an in-memory fake.
  final ProductsRepository? productsRepository;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE65100),
    );

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
      home: PosScreen(
        repository: repository,
        productsRepository: productsRepository,
      ),
    );
  }
}
