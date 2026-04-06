#!/usr/bin/env dart
// ABP Proxy Generator — CLI Entry Point

import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_abp_proxy/src/barrel_generator.dart';
import 'package:flutter_abp_proxy/src/config.dart';
import 'package:flutter_abp_proxy/src/fetch_api_definition.dart';
import 'package:flutter_abp_proxy/src/file_utils.dart';
import 'package:flutter_abp_proxy/src/lock_file.dart';
import 'package:flutter_abp_proxy/src/model_generator.dart';
import 'package:flutter_abp_proxy/src/service_generator.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('url', help: 'Base URL of the ABP backend')
    ..addOption('file', help: 'Load API definition from a local JSON file')
    ..addOption('token', help: 'Bearer token for authentication')
    ..addOption('output',
        defaultsTo: defaultOutputDir, help: 'Output directory')
    ..addOption('module', help: 'Only generate for this module root path')
    ..addMultiOption('include-modules',
        help: 'Only generate for these module root paths (repeatable)')
    ..addMultiOption('exclude-modules',
        help: 'Skip these module root paths (repeatable)')
    ..addFlag('unknown-enum-value',
        defaultsTo: true,
        help: 'Add unknown fallback member to generated enums')
    ..addOption('service-type',
        defaultsTo: 'application',
        allowed: ['application', 'integration', 'all'],
        help: 'Filter by service type')
    ..addFlag('clean',
        defaultsTo: false, help: 'Remove output directory before generating')
    ..addFlag('dry-run',
        defaultsTo: false, help: 'Preview files without writing')
    ..addFlag('skip-ssl',
        defaultsTo: false, help: 'Skip SSL certificate verification')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    print('Error: ${e.message}');
    print('Usage: flutter_abp_proxy --url <url> [options]');
    print(parser.usage);
    exit(1);
  }

  if (args.flag('help')) {
    print('ABP Proxy Generator for Flutter');
    print('');
    print('Usage: flutter_abp_proxy --url <url> [options]');
    print('');
    print(parser.usage);
    exit(0);
  }

  final url = args.option('url');
  final file = args.option('file');
  final token = args.option('token');
  final outputDir = p.absolute(args.option('output')!);
  final moduleFilter = args.option('module');
  final includeModules = args.multiOption('include-modules');
  final excludeModules = args.multiOption('exclude-modules');
  final unknownEnumValue = args.flag('unknown-enum-value');
  final serviceTypeStr = args.option('service-type')!;
  final serviceType = switch (serviceTypeStr) {
    'integration' => ServiceTypeFilter.integration,
    'all' => ServiceTypeFilter.all,
    _ => ServiceTypeFilter.application,
  };
  final clean = args.flag('clean');
  final dryRun = args.flag('dry-run');
  final skipSsl = args.flag('skip-ssl');

  if (url == null && file == null) {
    print('Error: --url or --file is required.');
    print('Usage: flutter_abp_proxy --url <url> [options]');
    print(parser.usage);
    exit(1);
  }

  // Resolve effective module filter
  String? effectiveModuleFilter = moduleFilter;
  if (moduleFilter != null &&
      (includeModules.isNotEmpty || excludeModules.isNotEmpty)) {
    print(
      'Warning: --module overrides --include-modules/--exclude-modules.',
    );
  }

  final sourceUrl = url ?? file ?? '';

  print('');
  print('=== ABP Proxy Generator for Flutter ===');
  print('Output: $outputDir');
  if (effectiveModuleFilter != null) {
    print('Module filter: $effectiveModuleFilter');
  }
  if (includeModules.isNotEmpty) {
    print('Include modules: ${includeModules.join(', ')}');
  }
  if (excludeModules.isNotEmpty) {
    print('Exclude modules: ${excludeModules.join(', ')}');
  }
  if (serviceType != ServiceTypeFilter.application) {
    print('Service type: $serviceTypeStr');
  }
  if (!unknownEnumValue) print('Unknown enum fallback: disabled');
  if (dryRun) print('Mode: DRY RUN (no files will be written)');
  print('');

  // Step 1: Fetch or load API definition
  Map<String, dynamic> apiDef;
  try {
    if (file != null) {
      print('Loading API definition from file: $file');
      apiDef = loadApiDefinitionFromFile(file);
    } else {
      apiDef = await fetchApiDefinition(
        url: url!,
        token: token,
        skipSsl: skipSsl,
      );
    }
  } catch (e) {
    print('\nFailed to get API definition: $e');
    exit(1);
  }

  // Step 1b: Apply include/exclude module filters
  if (effectiveModuleFilter == null && includeModules.isNotEmpty) {
    _filterModules(apiDef, include: includeModules);
  } else if (effectiveModuleFilter == null && excludeModules.isNotEmpty) {
    _filterModules(apiDef, exclude: excludeModules);
  }

  // Quick stats
  final modules = apiDef['modules'] as Map<String, dynamic>? ?? {};
  final types = apiDef['types'] as Map<String, dynamic>? ?? {};
  var actionCount = 0;
  for (final mod in modules.values) {
    final m = mod as Map<String, dynamic>;
    for (final ctrl
        in (m['controllers'] as Map<String, dynamic>? ?? {}).values) {
      final c = ctrl as Map<String, dynamic>;
      actionCount += (c['actions'] as Map<String, dynamic>? ?? {}).length;
    }
  }
  print(
    '  Modules: ${modules.length}, Types: ${types.length}, Actions: $actionCount',
  );
  print('');

  // Step 2: Clean output directory if requested
  if (clean && !dryRun) {
    print('Cleaning output directory...');
    cleanDir(outputDir);
  }

  // Step 3: Generate models (DTOs + enums)
  print('Generating models...');
  final modelResult = generateModels(
    apiDef,
    outputDir,
    dryRun: dryRun,
    sourceUrl: sourceUrl,
    unknownEnumValue: unknownEnumValue,
  );

  // Step 4: Generate services
  print('Generating services...');
  final serviceResult = generateServices(
    apiDef,
    outputDir,
    modelResult.typeLocations,
    dryRun: dryRun,
    sourceUrl: sourceUrl,
    moduleFilter: effectiveModuleFilter,
    serviceType: serviceType,
  );

  // Step 5: Generate barrel exports
  print('Generating barrel exports...');
  final barrelResult = generateBarrels(
    outputDir,
    dryRun: dryRun,
    sourceUrl: sourceUrl,
  );

  // Step 6: Write lock file
  writeLockFile(
    outputDir,
    sourceUrl: sourceUrl,
    apiDef: apiDef,
    modelCount: modelResult.files.length,
    serviceCount: serviceResult.files.length,
    dryRun: dryRun,
  );

  // Summary
  final allFiles = [
    ...modelResult.files,
    ...serviceResult.files,
    ...barrelResult.files,
  ];
  final writtenCount = allFiles.where((f) => f.written).length;

  print('');
  print('=== Generation Complete ===');
  print('  Models:   ${modelResult.files.length} files');
  print('  Services: ${serviceResult.files.length} files');
  print('  Barrels:  ${barrelResult.files.length} files');
  print('  Total:    ${allFiles.length} files');
  if (dryRun) {
    final skippedCount = allFiles.where((f) => !f.written).length;
    print('  (dry run — $skippedCount files would be written)');
  } else {
    print('  Written:  $writtenCount files');
  }
  print('');
  print('Next steps:');
  print('  1. Ensure your build.yaml has the correct generator ordering:');
  print('');
  print('     global_options:');
  print('       freezed:');
  print('         runs_before:');
  print('           - json_serializable');
  print('       json_serializable:');
  print('         runs_before:');
  print('           - retrofit_generator');
  print('');
  print(
    '  2. Run: dart run build_runner build --delete-conflicting-outputs',
  );
  print('  3. Run: flutter analyze');
}

/// Filter modules in the API definition by include/exclude lists.
void _filterModules(
  Map<String, dynamic> apiDef, {
  List<String>? include,
  List<String>? exclude,
}) {
  final modules = apiDef['modules'] as Map<String, dynamic>?;
  if (modules == null) return;

  final keysToRemove = <String>[];
  for (final entry in modules.entries) {
    final mod = entry.value as Map<String, dynamic>;
    final rootPath = mod['rootPath'] as String? ?? '';
    final kebabRoot = rootPath
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]}-${m[2]}',
        )
        .toLowerCase();

    if (include != null && include.isNotEmpty) {
      if (!include.contains(rootPath) && !include.contains(kebabRoot)) {
        keysToRemove.add(entry.key);
      }
    } else if (exclude != null && exclude.isNotEmpty) {
      if (exclude.contains(rootPath) || exclude.contains(kebabRoot)) {
        keysToRemove.add(entry.key);
      }
    }
  }

  for (final key in keysToRemove) {
    modules.remove(key);
  }
}
