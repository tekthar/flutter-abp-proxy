import 'dart:io';

import 'package:flutter_abp_proxy/src/service_generator.dart';
import 'package:test/test.dart';

void main() {
  group('ServiceTypeFilter', () {
    test('has all expected values', () {
      expect(ServiceTypeFilter.values, hasLength(3));
      expect(ServiceTypeFilter.values,
          containsAll([
            ServiceTypeFilter.application,
            ServiceTypeFilter.integration,
            ServiceTypeFilter.all,
          ]));
    });
  });

  group('generateServices', () {
    test('generates service file in dry-run', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{},
        'modules': <String, dynamic>{
          'product': {
            'rootPath': 'product',
            'controllers': {
              'ProductController': {
                'controllerName': 'ProductController',
                'controllerGroupName': 'Product',
                'actions': {
                  'GetList': {
                    'uniqueName': 'GetList',
                    'name': 'GetList',
                    'httpMethod': 'GET',
                    'url': '/api/product',
                    'parameters': [],
                    'returnValue': {
                      'type': 'System.String',
                      'typeSimple': 'string',
                    },
                  },
                },
              },
            },
          },
        },
      };

      final result = generateServices(
        apiDef,
        '/tmp/output',
        {},
        dryRun: true,
      );
      expect(result.files, hasLength(1));
      expect(result.files[0].filePath, contains('product_service.dart'));
      expect(result.files[0].written, false);
    });

    test('filters by module name', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{},
        'modules': <String, dynamic>{
          'product': {
            'rootPath': 'product',
            'controllers': <String, dynamic>{
              'ProductController': <String, dynamic>{
                'controllerName': 'ProductController',
                'controllerGroupName': 'Product',
                'actions': <String, dynamic>{},
              },
            },
          },
          'order': {
            'rootPath': 'order',
            'controllers': <String, dynamic>{
              'OrderController': <String, dynamic>{
                'controllerName': 'OrderController',
                'controllerGroupName': 'Order',
                'actions': <String, dynamic>{},
              },
            },
          },
        },
      };

      final result = generateServices(
        apiDef,
        '/tmp/output',
        {},
        dryRun: true,
        moduleFilter: 'product',
      );
      expect(result.files, hasLength(1));
      expect(result.files[0].filePath, contains('product'));
    });

    test('filters integration services', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{},
        'modules': <String, dynamic>{
          'product': {
            'rootPath': 'product',
            'controllers': <String, dynamic>{
              'ProductController': <String, dynamic>{
                'controllerName': 'ProductController',
                'controllerGroupName': 'Product',
                'isIntegrationService': false,
                'actions': <String, dynamic>{},
              },
              'ProductIntegrationService': <String, dynamic>{
                'controllerName': 'ProductIntegrationService',
                'controllerGroupName': 'ProductIntegration',
                'isIntegrationService': true,
                'actions': <String, dynamic>{},
              },
            },
          },
        },
      };

      // Application only (default)
      final appResult = generateServices(
        apiDef,
        '/tmp/output',
        {},
        dryRun: true,
        serviceType: ServiceTypeFilter.application,
      );
      expect(appResult.files, hasLength(1));
      expect(appResult.files[0].filePath, contains('product_service'));

      // Integration only
      final intResult = generateServices(
        apiDef,
        '/tmp/output',
        {},
        dryRun: true,
        serviceType: ServiceTypeFilter.integration,
      );
      expect(intResult.files, hasLength(1));
      expect(intResult.files[0].filePath,
          contains('product-integration'));

      // All
      final allResult = generateServices(
        apiDef,
        '/tmp/output',
        {},
        dryRun: true,
        serviceType: ServiceTypeFilter.all,
      );
      expect(allResult.files, hasLength(2));
    });

    test('generates methods with parameters', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{},
        'modules': <String, dynamic>{
          'product': {
            'rootPath': 'product',
            'controllers': {
              'ProductController': {
                'controllerName': 'ProductController',
                'controllerGroupName': 'Product',
                'actions': {
                  'GetById': {
                    'uniqueName': 'GetById',
                    'name': 'GetById',
                    'httpMethod': 'GET',
                    'url': '/api/product/{id}',
                    'parameters': [
                      {
                        'name': 'id',
                        'type': 'System.Guid',
                        'typeSimple': 'string',
                        'bindingSourceId': 'Path',
                        'isRequired': true,
                      },
                    ],
                    'returnValue': {
                      'type': 'System.String',
                      'typeSimple': 'string',
                    },
                  },
                  'Create': {
                    'uniqueName': 'Create',
                    'name': 'Create',
                    'httpMethod': 'POST',
                    'url': '/api/product',
                    'parameters': [
                      {
                        'name': 'input',
                        'type': 'System.String',
                        'typeSimple': 'string',
                        'bindingSourceId': 'Body',
                        'isRequired': true,
                      },
                    ],
                    'returnValue': {
                      'type': 'System.String',
                      'typeSimple': 'string',
                    },
                  },
                },
              },
            },
          },
        },
      };

      final result = generateServices(
        apiDef,
        '/tmp/output',
        {},
        dryRun: true,
      );
      expect(result.files, hasLength(1));
    });

    test('handles empty modules', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{},
        'modules': <String, dynamic>{},
      };

      final result = generateServices(apiDef, '/tmp/output', {}, dryRun: true);
      expect(result.files, isEmpty);
    });
  });

    test('does not produce double nullable types (Type??)', () {
      final tmpDir = Directory.systemTemp.createTempSync('abp_proxy_test_');
      try {
        final apiDef = <String, dynamic>{
          'types': <String, dynamic>{},
          'modules': <String, dynamic>{
            'product': {
              'rootPath': 'product',
              'controllers': <String, dynamic>{
                'ProductController': <String, dynamic>{
                  'controllerName': 'ProductController',
                  'controllerGroupName': 'Product',
                  'actions': <String, dynamic>{
                    'GetList': <String, dynamic>{
                      'uniqueName': 'GetList',
                      'name': 'GetList',
                      'httpMethod': 'GET',
                      'url': '/api/product',
                      'parameters': [
                        {
                          'name': 'StartTime',
                          'type': 'System.DateTime',
                          'typeSimple': 'date?',
                          'bindingSourceId': 'Query',
                          'isRequired': false,
                        },
                        {
                          'name': 'IsActive',
                          'type': 'System.Nullable<System.Boolean>',
                          'typeSimple': 'boolean?',
                          'bindingSourceId': 'Query',
                          'isRequired': false,
                        },
                        {
                          'name': 'Filter',
                          'type': 'System.String',
                          'typeSimple': 'string',
                          'bindingSourceId': 'Query',
                          'isRequired': false,
                        },
                      ],
                      'returnValue': {
                        'type': 'System.String',
                        'typeSimple': 'string',
                      },
                    },
                  },
                },
              },
            },
          },
        };

        final result = generateServices(
          apiDef,
          tmpDir.path,
          {},
        );

        expect(result.files, hasLength(1));
        final content = File(result.files[0].filePath).readAsStringSync();

        // Must not contain double nullable (??)
        expect(content, isNot(contains('??')));

        // Should contain single nullable for optional params
        expect(content, contains('DateTime?'));
        expect(content, contains('bool?'));
        expect(content, contains('String?'));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

  group('ServiceGenerationResult', () {
    test('stores files list', () {
      const result = ServiceGenerationResult(files: []);
      expect(result.files, isEmpty);
    });
  });
}
