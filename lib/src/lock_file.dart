/// ABP Proxy Generator — Lock File.
///
/// Tracks which modules were generated and from which API definition,
/// enabling incremental regeneration and drift detection.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The lock file name written alongside generated proxy output.
const lockFileName = 'generate-proxy.json';

/// Data stored in the lock file.
class ProxyLockFile {
  final String generatedAt;
  final String sourceUrl;
  final String generatorVersion;
  final List<String> generatedModules;
  final Map<String, int> moduleCounts;

  const ProxyLockFile({
    required this.generatedAt,
    required this.sourceUrl,
    required this.generatorVersion,
    required this.generatedModules,
    required this.moduleCounts,
  });

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt,
        'sourceUrl': sourceUrl,
        'generatorVersion': generatorVersion,
        'generatedModules': generatedModules,
        'moduleCounts': moduleCounts,
      };

  factory ProxyLockFile.fromJson(Map<String, dynamic> json) => ProxyLockFile(
        generatedAt: json['generatedAt'] as String? ?? '',
        sourceUrl: json['sourceUrl'] as String? ?? '',
        generatorVersion: json['generatorVersion'] as String? ?? '',
        generatedModules:
            (json['generatedModules'] as List<dynamic>?)?.cast<String>() ?? [],
        moduleCounts: (json['moduleCounts'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as int),
            ) ??
            {},
      );
}

/// Write the lock file to the output directory.
void writeLockFile(
  String outputDir, {
  required String sourceUrl,
  required Map<String, dynamic> apiDef,
  required int modelCount,
  required int serviceCount,
  bool dryRun = false,
}) {
  final modules = apiDef['modules'] as Map<String, dynamic>? ?? {};
  final generatedModules = <String>[];
  final moduleCounts = <String, int>{};

  for (final entry in modules.entries) {
    final mod = entry.value as Map<String, dynamic>;
    final rootPath = mod['rootPath'] as String? ?? entry.key;
    generatedModules.add(rootPath);

    var actionCount = 0;
    final controllers = mod['controllers'] as Map<String, dynamic>? ?? {};
    for (final ctrl in controllers.values) {
      final c = ctrl as Map<String, dynamic>;
      actionCount += (c['actions'] as Map<String, dynamic>? ?? {}).length;
    }
    moduleCounts[rootPath] = actionCount;
  }

  final lockFile = ProxyLockFile(
    generatedAt: DateTime.now().toUtc().toIso8601String(),
    sourceUrl: sourceUrl,
    generatorVersion: '0.1.0',
    generatedModules: generatedModules,
    moduleCounts: moduleCounts,
  );

  final filePath = p.join(outputDir, lockFileName);
  if (dryRun) {
    print('  [dry-run] Would write: $filePath');
    return;
  }

  final dir = Directory(p.dirname(filePath));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  File(filePath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(lockFile.toJson()),
  );
}

/// Read an existing lock file, or null if it doesn't exist.
ProxyLockFile? readLockFile(String outputDir) {
  final filePath = p.join(outputDir, lockFileName);
  final file = File(filePath);
  if (!file.existsSync()) return null;

  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return ProxyLockFile.fromJson(json);
  } catch (_) {
    return null;
  }
}
