import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Points `path_provider` at a throwaway temp directory so tests never touch
/// the real app database.
void useTempAppSupportDirectory() {
  final directory = Directory.systemTemp.createTempSync('pochero_pos_lite_');
  PathProviderPlatform.instance = _TempPathProvider(directory.path);
}

class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationSupportPath() async => rootPath;

  @override
  Future<String?> getTemporaryPath() async => rootPath;
}
