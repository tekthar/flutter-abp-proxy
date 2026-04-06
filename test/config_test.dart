import 'package:flutter_abp_proxy/src/config.dart';
import 'package:test/test.dart';

void main() {
  group('primitiveTypeMap', () {
    test('maps all typeSimple shortcuts', () {
      expect(primitiveTypeMap['string'], 'String');
      expect(primitiveTypeMap['boolean'], 'bool');
      expect(primitiveTypeMap['number'], 'int');
      expect(primitiveTypeMap['date'], 'DateTime');
      expect(primitiveTypeMap['object'], 'dynamic');
      expect(primitiveTypeMap['void'], 'void');
    });

    test('maps core .NET types', () {
      expect(primitiveTypeMap['System.String'], 'String');
      expect(primitiveTypeMap['System.Guid'], 'String');
      expect(primitiveTypeMap['System.Boolean'], 'bool');
      expect(primitiveTypeMap['System.Int32'], 'int');
      expect(primitiveTypeMap['System.Int64'], 'int');
      expect(primitiveTypeMap['System.Double'], 'double');
      expect(primitiveTypeMap['System.Decimal'], 'double');
      expect(primitiveTypeMap['System.DateTime'], 'DateTime');
      expect(primitiveTypeMap['System.DateTimeOffset'], 'DateTime');
      expect(primitiveTypeMap['System.TimeSpan'], 'String');
    });

    test('maps ASP.NET types', () {
      expect(
        primitiveTypeMap['Microsoft.AspNetCore.Http.IFormFile'],
        'File',
      );
    });

    test('maps ABP framework types', () {
      expect(
        primitiveTypeMap['Volo.Abp.Content.IRemoteStreamContent'],
        'List<int>',
      );
      expect(
        primitiveTypeMap['Volo.Abp.Data.ExtraPropertyDictionary'],
        'Map<String, dynamic>',
      );
    });
  });

  group('abpSharedTypes', () {
    test('contains essential ABP shared types', () {
      expect(abpSharedTypes, contains('PagedResultDto'));
      expect(abpSharedTypes, contains('ListResultDto'));
      expect(abpSharedTypes, contains('EntityDto'));
      expect(abpSharedTypes, contains('AuditedEntityDto'));
      expect(abpSharedTypes, contains('FullAuditedEntityDto'));
      expect(abpSharedTypes, contains('NameValue'));
    });
  });

  group('collectionTypes', () {
    test('contains standard .NET collection types', () {
      expect(collectionTypes,
          contains('System.Collections.Generic.List'));
      expect(collectionTypes,
          contains('System.Collections.Generic.IList'));
      expect(collectionTypes,
          contains('System.Collections.Generic.IEnumerable'));
      expect(collectionTypes,
          contains('System.Collections.Generic.HashSet'));
    });
  });

  group('dictionaryTypes', () {
    test('contains standard .NET dictionary types', () {
      expect(dictionaryTypes,
          contains('System.Collections.Generic.Dictionary'));
      expect(dictionaryTypes,
          contains('System.Collections.Generic.IDictionary'));
    });
  });

  group('skipTypes', () {
    test('contains types that should not be generated', () {
      expect(skipTypes,
          contains('System.Threading.CancellationToken'));
      expect(skipTypes,
          contains('Microsoft.AspNetCore.Mvc.ActionResult'));
    });
  });

  group('unwrapTypes', () {
    test('contains ActionResult for unwrapping', () {
      expect(unwrapTypes,
          contains('Microsoft.AspNetCore.Mvc.ActionResult'));
    });
  });

  group('constants', () {
    test('defaultOutputDir is set', () {
      expect(defaultOutputDir, 'lib/data/proxy');
    });

    test('apiDefinitionPath is set', () {
      expect(apiDefinitionPath,
          '/api/abp/api-definition?includeTypes=true');
    });

    test('bodyMethods contains POST, PUT, PATCH', () {
      expect(bodyMethods, containsAll(['POST', 'PUT', 'PATCH']));
    });
  });

  group('dartReservedWords', () {
    test('contains common Dart keywords', () {
      expect(dartReservedWords, contains('class'));
      expect(dartReservedWords, contains('void'));
      expect(dartReservedWords, contains('return'));
      expect(dartReservedWords, contains('final'));
      expect(dartReservedWords, contains('var'));
      expect(dartReservedWords, contains('enum'));
      expect(dartReservedWords, contains('abstract'));
    });
  });

  group('abpInheritedProps', () {
    test('EntityDto has Id', () {
      expect(abpInheritedProps['EntityDto'], ['Id']);
    });

    test('AuditedEntityDto has audit properties', () {
      expect(
        abpInheritedProps['AuditedEntityDto'],
        containsAll([
          'Id',
          'CreationTime',
          'CreatorId',
          'LastModificationTime',
          'LastModifierId',
        ]),
      );
    });

    test('FullAuditedEntityDto has soft-delete properties', () {
      expect(
        abpInheritedProps['FullAuditedEntityDto'],
        containsAll(['IsDeleted', 'DeleterId', 'DeletionTime']),
      );
    });
  });

  group('streamContentTypes', () {
    test('contains ABP stream content types', () {
      expect(streamContentTypes,
          contains('Volo.Abp.Content.IRemoteStreamContent'));
      expect(streamContentTypes,
          contains('Microsoft.AspNetCore.Http.IFormFile'));
    });
  });
}
