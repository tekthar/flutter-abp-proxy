import 'package:flutter_abp_proxy/src/lock_file.dart';
import 'package:test/test.dart';

void main() {
  group('ProxyLockFile', () {
    test('serializes to JSON', () {
      const lockFile = ProxyLockFile(
        generatedAt: '2026-01-01T00:00:00.000Z',
        sourceUrl: 'https://example.com',
        generatorVersion: '0.1.0',
        generatedModules: ['product', 'order'],
        moduleCounts: {'product': 5, 'order': 3},
      );

      final json = lockFile.toJson();
      expect(json['generatedAt'], '2026-01-01T00:00:00.000Z');
      expect(json['sourceUrl'], 'https://example.com');
      expect(json['generatorVersion'], '0.1.0');
      expect(json['generatedModules'], ['product', 'order']);
      expect(json['moduleCounts'], {'product': 5, 'order': 3});
    });

    test('deserializes from JSON', () {
      final json = <String, dynamic>{
        'generatedAt': '2026-01-01T00:00:00.000Z',
        'sourceUrl': 'https://example.com',
        'generatorVersion': '0.1.0',
        'generatedModules': ['product'],
        'moduleCounts': {'product': 5},
      };

      final lockFile = ProxyLockFile.fromJson(json);
      expect(lockFile.generatedAt, '2026-01-01T00:00:00.000Z');
      expect(lockFile.sourceUrl, 'https://example.com');
      expect(lockFile.generatorVersion, '0.1.0');
      expect(lockFile.generatedModules, ['product']);
      expect(lockFile.moduleCounts, {'product': 5});
    });

    test('handles missing fields with defaults', () {
      final lockFile = ProxyLockFile.fromJson(<String, dynamic>{});
      expect(lockFile.generatedAt, '');
      expect(lockFile.sourceUrl, '');
      expect(lockFile.generatorVersion, '');
      expect(lockFile.generatedModules, isEmpty);
      expect(lockFile.moduleCounts, isEmpty);
    });

    test('roundtrips through JSON', () {
      const original = ProxyLockFile(
        generatedAt: '2026-04-07T12:00:00.000Z',
        sourceUrl: 'https://api.example.com',
        generatorVersion: '0.1.0',
        generatedModules: ['identity', 'saas'],
        moduleCounts: {'identity': 10, 'saas': 7},
      );

      final restored = ProxyLockFile.fromJson(original.toJson());
      expect(restored.generatedAt, original.generatedAt);
      expect(restored.sourceUrl, original.sourceUrl);
      expect(restored.generatorVersion, original.generatorVersion);
      expect(restored.generatedModules, original.generatedModules);
      expect(restored.moduleCounts, original.moduleCounts);
    });
  });

  group('readLockFile', () {
    test('returns null for non-existent directory', () {
      final result = readLockFile('/tmp/nonexistent_dir_12345');
      expect(result, isNull);
    });
  });
}
