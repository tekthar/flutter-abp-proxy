/// Example: Using flutter_abp_proxy programmatically.
///
/// This package is primarily used as a CLI tool via:
///   dart pub global activate flutter_abp_proxy
///   flutter_abp_proxy --url https://your-abp-backend.com
///
/// But you can also use the library API directly:
library;

import 'dart:io';

import 'package:flutter_abp_proxy/flutter_abp_proxy.dart';

Future<void> main() async {
  // 1. Load API definition from a local JSON file (or use fetchApiDefinition
  //    for a running backend).
  final apiDef = loadApiDefinitionFromFile('api-definition.json');

  // 2. Generate Freezed model classes.
  final modelResult = generateModels(
    apiDef,
    'lib/data/proxy',
    dryRun: true, // set to false to write files
    sourceUrl: 'https://your-abp-backend.com',
  );
  print('Models: ${modelResult.files.length} files');

  // 3. Generate Retrofit service classes.
  final serviceResult = generateServices(
    apiDef,
    'lib/data/proxy',
    modelResult.typeLocations,
    dryRun: true,
    sourceUrl: 'https://your-abp-backend.com',
  );
  print('Services: ${serviceResult.files.length} files');

  // 4. Generate barrel export files (only works when files exist on disk).
  if (!Platform.environment.containsKey('DRY_RUN')) {
    final barrelResult = generateBarrels(
      'lib/data/proxy',
      dryRun: true,
      sourceUrl: 'https://your-abp-backend.com',
    );
    print('Barrels: ${barrelResult.files.length} files');
  }

  // 5. Write a lock file for reproducibility.
  writeLockFile(
    'lib/data/proxy',
    sourceUrl: 'https://your-abp-backend.com',
    apiDef: apiDef,
    modelCount: modelResult.files.length,
    serviceCount: serviceResult.files.length,
    dryRun: true,
  );
}
