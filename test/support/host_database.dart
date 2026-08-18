import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initializeHostDatabase() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  PackageInfo.setMockInitialValues(
    appName: 'NextPlay',
    packageName: 'me.zqydev.nextplay.debug',
    version: '0.0.0-test',
    buildNumber: '0',
    buildSignature: 'test',
  );

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (_) async {
        return Directory.systemTemp.path;
      });
}
