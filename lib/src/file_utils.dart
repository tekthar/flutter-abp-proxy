/// ABP Proxy Generator — File Utilities.
///
/// Helpers for creating directories, writing generated files,
/// and cleaning output paths.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Ensure a directory exists, creating it recursively if needed.
void ensureDir(String dirPath) {
  Directory(dirPath).createSync(recursive: true);
}

/// Write a generated file. Creates parent directories if needed.
///
/// Returns a record with the file path and whether it was written.
({String filePath, bool written}) writeGeneratedFile(
  String filePath,
  String content, {
  bool dryRun = false,
}) {
  if (dryRun) {
    print('  [dry-run] Would write: $filePath');
    return (filePath: filePath, written: false);
  }
  ensureDir(p.dirname(filePath));
  File(filePath).writeAsStringSync(content);
  return (filePath: filePath, written: true);
}

/// Remove a directory and all its contents.
void cleanDir(String dirPath) {
  final dir = Directory(dirPath);
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
    print('  Cleaned: $dirPath');
  }
}

/// Get all .dart files in a directory (non-recursive), excluding barrel files.
List<String> getDartFiles(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];
  return dir
      .listSync()
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.dart') &&
            !p.basename(f.path).startsWith('_') &&
            p.basename(f.path) != 'barrel.dart',
      )
      .map((f) => p.basename(f.path))
      .toList();
}

/// Get all subdirectories in a directory.
List<String> getSubdirectories(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];
  return dir
      .listSync()
      .whereType<Directory>()
      .map((d) => p.basename(d.path))
      .toList();
}
