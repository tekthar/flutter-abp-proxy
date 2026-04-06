/// ABP Proxy Generator — Barrel Export Generator.
///
/// Generates barrel (index) export files for each directory under the
/// output path, re-exporting all generated models and services.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_utils.dart';

/// Result of barrel generation.
class BarrelGenerationResult {
  final List<({String filePath, bool written})> files;

  const BarrelGenerationResult({required this.files});
}

/// Generate barrel export files recursively.
BarrelGenerationResult generateBarrels(
  String outputDir, {
  bool dryRun = false,
  String sourceUrl = '',
}) {
  final files = <({String filePath, bool written})>[];
  _generateBarrelsRecursive(outputDir, outputDir, files, dryRun, sourceUrl, 0);
  return BarrelGenerationResult(files: files);
}

void _generateBarrelsRecursive(
  String rootDir,
  String currentDir,
  List<({String filePath, bool written})> files,
  bool dryRun,
  String sourceUrl,
  int depth,
) {
  final dir = Directory(currentDir);
  if (!dir.existsSync()) return;

  // Recurse into subdirectories first
  final subdirs = dir
      .listSync()
      .whereType<Directory>()
      .map((d) => p.basename(d.path))
      .toList()
    ..sort();

  for (final subdir in subdirs) {
    _generateBarrelsRecursive(
      rootDir,
      p.join(currentDir, subdir),
      files,
      dryRun,
      sourceUrl,
      depth + 1,
    );
  }

  // Collect .dart files in this directory (exclude generated files and barrels)
  final dartFiles = dir
      .listSync()
      .whereType<File>()
      .where((f) {
        final name = p.basename(f.path);
        return name.endsWith('.dart') &&
            !name.endsWith('.freezed.dart') &&
            !name.endsWith('.g.dart') &&
            name != 'barrel.dart';
      })
      .map((f) => p.basename(f.path))
      .toList()
    ..sort();

  // Build exports
  final exports = <String>[];

  // Export .dart files in this directory
  for (final file in dartFiles) {
    exports.add("export '$file';");
  }

  // Export subdirectory barrels
  for (final subdir in subdirs) {
    final subBarrel = p.join(currentDir, subdir, 'barrel.dart');
    if (File(subBarrel).existsSync() || !dryRun) {
      exports.add("export '$subdir/barrel.dart';");
    }
  }

  if (exports.isEmpty) return;

  // Skip barrel at root level (depth 0) to avoid issues
  // Actually, generate at all levels for convenience
  final buf = StringBuffer();
  buf.writeln('// GENERATED FILE — DO NOT EDIT BY HAND');
  buf.writeln('// Source: $sourceUrl');
  buf.writeln('// Generator: flutter_abp_proxy');
  buf.writeln();
  for (final export in exports) {
    buf.writeln(export);
  }

  final barrelPath = p.join(currentDir, 'barrel.dart');
  files.add(writeGeneratedFile(barrelPath, buf.toString(), dryRun: dryRun));
}
