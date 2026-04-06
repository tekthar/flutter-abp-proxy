import 'package:flutter_abp_proxy/src/type_mapper.dart';
import 'package:test/test.dart';

void main() {
  group('mapType', () {
    test('maps void types', () {
      final result = mapType(null, null, {});
      expect(result.dartType, 'void');
      expect(result.imports, isEmpty);
    });

    test('maps System.Void to void', () {
      final result = mapType('System.Void', null, {});
      expect(result.dartType, 'void');
    });

    test('maps primitive .NET types', () {
      expect(mapType('System.String', null, {}).dartType, 'String');
      expect(mapType('System.Int32', null, {}).dartType, 'int');
      expect(mapType('System.Boolean', null, {}).dartType, 'bool');
      expect(mapType('System.Double', null, {}).dartType, 'double');
      expect(mapType('System.DateTime', null, {}).dartType, 'DateTime');
      expect(mapType('System.Guid', null, {}).dartType, 'String');
      expect(mapType('System.Decimal', null, {}).dartType, 'double');
    });

    test('maps typeSimple shortcuts', () {
      expect(mapType('System.String', 'string', {}).dartType, 'String');
      expect(mapType('System.Boolean', 'boolean', {}).dartType, 'bool');
      expect(mapType('System.Int32', 'number', {}).dartType, 'int');
      expect(mapType('System.DateTime', 'date', {}).dartType, 'DateTime');
    });

    test('maps byte array to String (base64)', () {
      expect(mapType('System.Byte[]', null, {}).dartType, 'String');
      expect(mapType('[System.Byte]', null, {}).dartType, 'String');
    });

    test('maps ABP array notation in typeSimple', () {
      final result = mapType(
        'System.Collections.Generic.List<System.String>',
        '[string]',
        {},
      );
      expect(result.dartType, 'List<String>');
    });

    test('maps ABP nullable notation in typeSimple', () {
      final result = mapType('System.Nullable<System.String>', 'string?', {});
      expect(result.dartType, 'String?');
    });

    test('maps collection types to List', () {
      final result = mapType(
        'System.Collections.Generic.List<System.String>',
        null,
        {},
      );
      expect(result.dartType, 'List<String>');
    });

    test('maps IEnumerable to List', () {
      final result = mapType(
        'System.Collections.Generic.IEnumerable<System.Int32>',
        null,
        {},
      );
      expect(result.dartType, 'List<int>');
    });

    test('maps dictionary types to Map', () {
      final result = mapType(
        'System.Collections.Generic.Dictionary<System.String,System.Int32>',
        null,
        {},
      );
      expect(result.dartType, 'Map<String, int>');
    });

    test('maps Nullable<T> to T?', () {
      final result = mapType(
        'System.Nullable<System.Int32>',
        null,
        {},
      );
      expect(result.dartType, 'int?');
    });

    test('unwraps ActionResult<T>', () {
      final typesMap = <String, dynamic>{
        'MyApp.ProductDto': {
          'isEnum': false,
          'properties': [],
        },
      };
      final result = mapType(
        'Microsoft.AspNetCore.Mvc.ActionResult<MyApp.ProductDto>',
        null,
        typesMap,
      );
      expect(result.dartType, 'ProductDto');
    });

    test('maps user DTO from typesMap', () {
      final typesMap = <String, dynamic>{
        'MyApp.Dto.ProductDto': {
          'isEnum': false,
          'properties': [],
        },
      };
      final result = mapType('MyApp.Dto.ProductDto', null, typesMap);
      expect(result.dartType, 'ProductDto');
      expect(result.imports, hasLength(1));
      expect(result.imports[0].typeName, 'ProductDto');
      expect(result.imports[0].isEnum, false);
    });

    test('maps enum from typesMap', () {
      final typesMap = <String, dynamic>{
        'MyApp.Status': {
          'isEnum': true,
          'enumNames': ['Active', 'Inactive'],
          'enumValues': [0, 1],
        },
      };
      final result = mapType('MyApp.Status', null, typesMap);
      expect(result.dartType, 'Status');
      expect(result.imports, hasLength(1));
      expect(result.imports[0].isEnum, true);
    });

    test('maps ABP shared types', () {
      final result = mapType(
        'Volo.Abp.Application.Dtos.PagedResultDto<MyApp.ProductDto>',
        null,
        {
          'MyApp.ProductDto': {
            'isEnum': false,
            'properties': [],
          },
        },
      );
      expect(result.dartType, 'PagedResultDto<ProductDto>');
    });

    test('maps IFormFile to File', () {
      final result = mapType(
        'Microsoft.AspNetCore.Http.IFormFile',
        null,
        {},
      );
      expect(result.dartType, 'File');
    });

    test('maps ExtraPropertyDictionary to Map', () {
      final result = mapType(
        'Volo.Abp.Data.ExtraPropertyDictionary',
        null,
        {},
      );
      expect(result.dartType, 'Map<String, dynamic>');
    });

    test('returns dynamic for unknown types', () {
      final result = mapType('Some.Unknown.Type', null, {});
      expect(result.dartType, contains('dynamic'));
    });

    test('handles ABP dictionary notation', () {
      final result = mapType('{string:number}', null, {});
      // The curly-brace notation is handled via _resolveFullType
      expect(result.dartType, contains('Map'));
    });
  });

  group('TypeImport', () {
    test('stores type info correctly', () {
      const imp = TypeImport(
        typeName: 'ProductDto',
        isAbpShared: false,
        isEnum: false,
        fullName: 'MyApp.ProductDto',
      );
      expect(imp.typeName, 'ProductDto');
      expect(imp.isAbpShared, false);
      expect(imp.isEnum, false);
      expect(imp.fullName, 'MyApp.ProductDto');
    });
  });

  group('MappedType', () {
    test('stores dart type and imports', () {
      const mapped = MappedType(
        dartType: 'String',
        imports: [],
      );
      expect(mapped.dartType, 'String');
      expect(mapped.imports, isEmpty);
    });
  });
}
