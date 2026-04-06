import 'package:flutter_abp_proxy/src/model_generator.dart';
import 'package:test/test.dart';

void main() {
  group('generateModels', () {
    test('generates ABP shared types file in dry-run', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{},
        'modules': <String, dynamic>{},
      };

      final result = generateModels(apiDef, '/tmp/output', dryRun: true);
      expect(result.files, isNotEmpty);

      // Should include abp_types.dart and abp_error.dart
      final filePaths = result.files.map((f) => f.filePath).toList();
      expect(filePaths.any((p) => p.contains('abp_types.dart')), true);
      expect(filePaths.any((p) => p.contains('abp_error.dart')), true);
    });

    test('registers ABP shared type locations', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{},
        'modules': <String, dynamic>{},
      };

      final result = generateModels(apiDef, '/tmp/output', dryRun: true);
      expect(result.typeLocations['PagedResultDto'],
          './shared/models/abp_types');
      expect(result.typeLocations['ListResultDto'],
          './shared/models/abp_types');
      expect(result.typeLocations['EntityDto'],
          './shared/models/abp_types');
    });

    test('generates enum from API definition in dry-run', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{
          'MyApp.Status': {
            'isEnum': true,
            'enumNames': ['Active', 'Inactive'],
            'enumValues': [0, 1],
            'properties': [],
          },
        },
        'modules': <String, dynamic>{},
      };

      final result = generateModels(apiDef, '/tmp/output', dryRun: true);
      final filePaths = result.files.map((f) => f.filePath).toList();
      expect(filePaths.any((p) => p.contains('status.dart')), true);
    });

    test('generates model from API definition in dry-run', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{
          'MyApp.ProductDto': {
            'isEnum': false,
            'properties': [
              {
                'name': 'Name',
                'type': 'System.String',
                'typeSimple': 'string',
                'isRequired': true,
              },
              {
                'name': 'Price',
                'type': 'System.Decimal',
                'typeSimple': 'number',
                'isRequired': false,
              },
            ],
          },
        },
        'modules': <String, dynamic>{},
      };

      final result = generateModels(apiDef, '/tmp/output', dryRun: true);
      final filePaths = result.files.map((f) => f.filePath).toList();
      expect(filePaths.any((p) => p.contains('product_dto.dart')), true);
    });

    test('places type in controller group when used by one controller', () {
      final apiDef = <String, dynamic>{
        'types': <String, dynamic>{
          'MyApp.ProductDto': {
            'isEnum': false,
            'properties': [],
          },
        },
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
                      'type': 'MyApp.ProductDto',
                      'typeSimple': 'ProductDto',
                    },
                  },
                },
              },
            },
          },
        },
      };

      final result = generateModels(apiDef, '/tmp/output', dryRun: true);
      expect(
        result.typeLocations['ProductDto'],
        contains('product'),
      );
    });
  });

  group('buildControllerGroup', () {
    test('builds controller group path', () {
      final ctrl = <String, dynamic>{
        'controllerGroupName': 'Product',
        'controllerName': 'ProductController',
      };
      expect(buildControllerGroup(ctrl, 'app'), 'app/product');
    });

    test('uses controllerName as fallback', () {
      final ctrl = <String, dynamic>{
        'controllerName': 'OrderController',
      };
      expect(buildControllerGroup(ctrl, 'app'), 'app/order-controller');
    });

    test('converts rootPath to kebab-case', () {
      final ctrl = <String, dynamic>{
        'controllerGroupName': 'Product',
      };
      expect(buildControllerGroup(ctrl, 'MyModule'), 'my-module/product');
    });
  });

  group('ModelGenerationOptions', () {
    test('has correct defaults', () {
      const options = ModelGenerationOptions();
      expect(options.dryRun, false);
      expect(options.sourceUrl, '');
      expect(options.unknownEnumValue, true);
    });
  });

  group('dtoContainsStreamContent', () {
    test('returns false for null type', () {
      expect(dtoContainsStreamContent(null, {}), false);
    });

    test('returns false for empty type', () {
      expect(dtoContainsStreamContent('', {}), false);
    });

    test('detects IRemoteStreamContent directly', () {
      expect(
        dtoContainsStreamContent(
          'Volo.Abp.Content.IRemoteStreamContent',
          {},
        ),
        true,
      );
    });

    test('detects IFormFile directly', () {
      expect(
        dtoContainsStreamContent(
          'Microsoft.AspNetCore.Http.IFormFile',
          {},
        ),
        true,
      );
    });

    test('detects stream content in nested properties', () {
      final typesMap = <String, dynamic>{
        'MyApp.UploadDto': {
          'isEnum': false,
          'properties': [
            {
              'name': 'File',
              'type': 'Volo.Abp.Content.IRemoteStreamContent',
            },
            {
              'name': 'Name',
              'type': 'System.String',
            },
          ],
        },
      };
      expect(dtoContainsStreamContent('MyApp.UploadDto', typesMap), true);
    });

    test('returns false for DTO without stream content', () {
      final typesMap = <String, dynamic>{
        'MyApp.ProductDto': {
          'isEnum': false,
          'properties': [
            {
              'name': 'Name',
              'type': 'System.String',
            },
          ],
        },
      };
      expect(
          dtoContainsStreamContent('MyApp.ProductDto', typesMap), false);
    });
  });
}
