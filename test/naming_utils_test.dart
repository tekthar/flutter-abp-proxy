import 'package:flutter_abp_proxy/src/naming_utils.dart';
import 'package:test/test.dart';

void main() {
  group('pascalToCamel', () {
    test('converts PascalCase to camelCase', () {
      expect(pascalToCamel('ProductDto'), 'productDto');
      expect(pascalToCamel('MyClassName'), 'myClassName');
    });

    test('returns empty for empty string', () {
      expect(pascalToCamel(''), '');
    });

    test('handles single character', () {
      expect(pascalToCamel('A'), 'a');
    });

    test('preserves already camelCase', () {
      expect(pascalToCamel('alreadyCamel'), 'alreadyCamel');
    });
  });

  group('pascalToSnake', () {
    test('converts PascalCase to snake_case', () {
      expect(pascalToSnake('ProductDto'), 'product_dto');
      expect(pascalToSnake('MyClassName'), 'my_class_name');
    });

    test('handles consecutive uppercase letters', () {
      expect(pascalToSnake('HTMLParser'), 'html_parser');
      expect(pascalToSnake('ABCDef'), 'abc_def');
    });

    test('returns empty for empty string', () {
      expect(pascalToSnake(''), '');
    });

    test('handles digits between letters', () {
      expect(pascalToSnake('Base64Encoder'), 'base64_encoder');
    });
  });

  group('pascalToKebab', () {
    test('converts PascalCase to kebab-case', () {
      expect(pascalToKebab('ProductDto'), 'product-dto');
      expect(pascalToKebab('MyClassName'), 'my-class-name');
    });

    test('handles consecutive uppercase letters', () {
      expect(pascalToKebab('HTMLParser'), 'html-parser');
    });

    test('returns empty for empty string', () {
      expect(pascalToKebab(''), '');
    });
  });

  group('stripAsyncSuffix', () {
    test('strips Async suffix', () {
      expect(stripAsyncSuffix('GetListAsync'), 'GetList');
      expect(stripAsyncSuffix('CreateAsync'), 'Create');
    });

    test('preserves names without Async suffix', () {
      expect(stripAsyncSuffix('GetList'), 'GetList');
    });

    test('returns empty for empty string', () {
      expect(stripAsyncSuffix(''), '');
    });
  });

  group('stripAssemblyVersion', () {
    test('removes Version segments', () {
      expect(
        stripAssemblyVersion('MyDto, MyApp.Contracts, Version=1.5.92.0'),
        'MyDto, MyApp.Contracts',
      );
    });

    test('removes Culture and PublicKeyToken', () {
      expect(
        stripAssemblyVersion(
          'MyDto, Culture=neutral, PublicKeyToken=null',
        ),
        'MyDto',
      );
    });

    test('preserves clean type names', () {
      expect(stripAssemblyVersion('System.String'), 'System.String');
    });
  });

  group('normalizeNestedClassName', () {
    test('removes plus delimiter', () {
      expect(normalizeNestedClassName('MyController+InnerClass'),
          'MyControllerInnerClass');
    });

    test('preserves names without plus', () {
      expect(normalizeNestedClassName('MyClass'), 'MyClass');
    });
  });

  group('extractShortTypeName', () {
    test('extracts short name from namespace', () {
      expect(extractShortTypeName('MyApp.Dto.ProductDto'), 'ProductDto');
    });

    test('strips generic args', () {
      expect(
        extractShortTypeName('MyApp.Dto.ProductDto<System.Guid>'),
        'ProductDto',
      );
    });

    test('handles nested class delimiter', () {
      expect(
        extractShortTypeName('MyApp.MyController+InnerDto'),
        'InnerDto',
      );
    });

    test('returns name if no namespace', () {
      expect(extractShortTypeName('ProductDto'), 'ProductDto');
    });

    test('returns empty for empty string', () {
      expect(extractShortTypeName(''), '');
    });
  });

  group('extractNamespace', () {
    test('extracts namespace', () {
      expect(extractNamespace('MyApp.Dto.ProductDto'), 'MyApp.Dto');
    });

    test('returns empty if no namespace', () {
      expect(extractNamespace('ProductDto'), '');
    });

    test('strips generic args before extracting', () {
      expect(
        extractNamespace('MyApp.Dto.ProductDto<System.Guid>'),
        'MyApp.Dto',
      );
    });

    test('returns empty for empty string', () {
      expect(extractNamespace(''), '');
    });
  });

  group('parseGenericType', () {
    test('parses simple generic type', () {
      final result = parseGenericType('PagedResultDto<ProductDto>');
      expect(result.base, 'PagedResultDto');
      expect(result.args, ['ProductDto']);
    });

    test('parses nested generic type', () {
      final result =
          parseGenericType('Dictionary<String,List<Int32>>');
      expect(result.base, 'Dictionary');
      expect(result.args, ['String', 'List<Int32>']);
    });

    test('returns base only for non-generic', () {
      final result = parseGenericType('ProductDto');
      expect(result.base, 'ProductDto');
      expect(result.args, isEmpty);
    });

    test('returns empty for empty string', () {
      final result = parseGenericType('');
      expect(result.base, '');
      expect(result.args, isEmpty);
    });

    test('handles multiple type args', () {
      final result = parseGenericType('Map<String,Int32>');
      expect(result.base, 'Map');
      expect(result.args, ['String', 'Int32']);
    });
  });

  group('typeNameToFileName', () {
    test('converts type name to snake_case file name', () {
      expect(typeNameToFileName('ProductDto'), 'product_dto');
      expect(typeNameToFileName('MyServiceProxy'), 'my_service_proxy');
    });
  });

  group('controllerToGroupName', () {
    test('strips Controller suffix', () {
      expect(controllerToGroupName('ProductController'), 'product');
    });

    test('strips AppService suffix', () {
      expect(controllerToGroupName('ProductAppService'), 'product');
    });

    test('preserves names without known suffix', () {
      expect(controllerToGroupName('ProductManager'), 'product-manager');
    });
  });

  group('sanitizeIdentifier', () {
    test('replaces invalid characters with underscore', () {
      expect(sanitizeIdentifier('my-var'), 'my_var');
      expect(sanitizeIdentifier('my.var'), 'my_var');
    });

    test('prefixes with underscore when starting with digit', () {
      expect(sanitizeIdentifier('123abc'), '_123abc');
    });

    test('returns underscore for empty string', () {
      expect(sanitizeIdentifier(''), '_');
    });

    test('preserves valid identifiers', () {
      expect(sanitizeIdentifier('myVar'), 'myVar');
      expect(sanitizeIdentifier('_private'), '_private');
      expect(sanitizeIdentifier('\$value'), '\$value');
    });
  });
}
