/// ABP Proxy Generator — Configuration & Constants.
///
/// Contains type mappings, reserved words, and default settings
/// used throughout the code generation process.
library;

/// Map of .NET primitive types to Dart types.
const primitiveTypeMap = <String, String>{
  // typeSimple shortcuts
  'string': 'String',
  'boolean': 'bool',
  'number': 'int',
  'date': 'DateTime',
  'object': 'dynamic',
  'void': 'void',

  // Full .NET type names
  'System.String': 'String',
  'System.Guid': 'String',
  'System.Boolean': 'bool',
  'System.Byte': 'int',
  'System.SByte': 'int',
  'System.Int16': 'int',
  'System.Int32': 'int',
  'System.Int64': 'int',
  'System.UInt16': 'int',
  'System.UInt32': 'int',
  'System.UInt64': 'int',
  'System.Single': 'double',
  'System.Double': 'double',
  'System.Decimal': 'double',
  'System.DateTime': 'DateTime',
  'System.DateTimeOffset': 'DateTime',
  'System.TimeSpan': 'String',
  'System.Char': 'String',
  'System.Object': 'dynamic',
  'System.Void': 'void',
  'System.Uri': 'String',
  'System.Type': 'String',

  // ASP.NET / .NET framework types
  'Microsoft.AspNetCore.Http.IFormFile': 'File',
  'System.Text.Json.JsonElement': 'dynamic',
  'System.Text.Json.JsonDocument': 'dynamic',
  'Microsoft.Extensions.Primitives.StringSegment': 'String',
  'Microsoft.Extensions.Primitives.StringValues': 'String',
  'System.ValueType': 'dynamic',
  'System.Threading.CancellationToken': 'dynamic',

  // ABP framework types
  'Volo.Abp.Content.IRemoteStreamContent': 'List<int>',
  'Volo.Abp.Data.ExtraPropertyDictionary': 'Map<String, dynamic>',
};

/// ABP framework generic types that live in `shared/models/abp_types.dart`.
const abpSharedTypes = <String>[
  'PagedResultDto',
  'ListResultDto',
  'PagedResultRequestDto',
  'LimitedResultRequestDto',
  'PagedAndSortedResultRequestDto',
  'EntityDto',
  'CreationAuditedEntityDto',
  'AuditedEntityDto',
  'FullAuditedEntityDto',
  'AuditedEntityWithUserDto',
  'CreationAuditedEntityWithUserDto',
  'ExtensibleObject',
  'ExtensibleEntityDto',
  'ExtensibleCreationAuditedEntityDto',
  'ExtensibleAuditedEntityDto',
  'ExtensibleFullAuditedEntityDto',
  'ExtensiblePagedAndSortedResultRequestDto',
  'NameValue',
];

/// .NET collection types that map to `List<T>`.
const collectionTypes = <String>[
  'System.Collections.Generic.List',
  'System.Collections.Generic.IList',
  'System.Collections.Generic.ICollection',
  'System.Collections.Generic.IEnumerable',
  'System.Collections.Generic.IReadOnlyList',
  'System.Collections.Generic.IReadOnlyCollection',
  'System.Collections.Generic.HashSet',
  'System.Collections.Generic.ISet',
];

/// .NET dictionary types that map to `Map<K, V>`.
const dictionaryTypes = <String>[
  'System.Collections.Generic.Dictionary',
  'System.Collections.Generic.IDictionary',
  'System.Collections.Generic.IReadOnlyDictionary',
];

/// .NET/ASP.NET framework types that should NOT be generated as classes.
const skipTypes = <String>[
  'System.Threading.CancellationToken',
  'Microsoft.AspNetCore.Mvc.ActionResult',
  'Microsoft.AspNetCore.Mvc.IActionResult',
  'Microsoft.AspNetCore.Http.IFormFile',
  'Microsoft.Extensions.Primitives.StringValues',
  'Microsoft.Extensions.Primitives.StringSegment',
  'System.Text.Json.JsonElement',
  'System.Text.Json.JsonDocument',
  'System.ValueType',
  'System.Enum',
  'System.Nullable',
  'System.Collections.Generic.KeyValuePair',
  'Volo.Abp.Data.ExtraPropertyDictionary',
  'Volo.Abp.Content.IRemoteStreamContent',
];

/// Generic wrapper types to unwrap: `ActionResult<T>` -> `T`.
const unwrapTypes = <String>[
  'Microsoft.AspNetCore.Mvc.ActionResult',
];

/// Default configuration values.
const defaultOutputDir = 'lib/data/proxy';
const apiDefinitionPath = '/api/abp/api-definition?includeTypes=true';

/// HTTP methods that typically have a request body.
const bodyMethods = <String>['POST', 'PUT', 'PATCH'];

/// .NET types that indicate file/stream content (trigger multipart detection).
const streamContentTypes = <String>[
  'Volo.Abp.Content.IRemoteStreamContent',
  'Volo.Abp.Content.RemoteStreamContent',
  'Microsoft.AspNetCore.Http.IFormFile',
];

/// Dart reserved words that cannot be used as enum member names.
const dartReservedWords = <String>{
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'type',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// Known properties from ABP shared base types (PascalCase as in API definition).
const abpInheritedProps = <String, List<String>>{
  'EntityDto': ['Id'],
  'CreationAuditedEntityDto': ['Id', 'CreationTime', 'CreatorId'],
  'CreationAuditedEntityWithUserDto': [
    'Id',
    'CreationTime',
    'CreatorId',
    'Creator',
  ],
  'AuditedEntityDto': [
    'Id',
    'CreationTime',
    'CreatorId',
    'LastModificationTime',
    'LastModifierId',
  ],
  'AuditedEntityWithUserDto': [
    'Id',
    'CreationTime',
    'CreatorId',
    'Creator',
    'LastModificationTime',
    'LastModifierId',
    'LastModifier',
  ],
  'FullAuditedEntityDto': [
    'Id',
    'CreationTime',
    'CreatorId',
    'LastModificationTime',
    'LastModifierId',
    'IsDeleted',
    'DeleterId',
    'DeletionTime',
  ],
  'ExtensibleEntityDto': ['Id', 'ExtraProperties'],
  'ExtensibleCreationAuditedEntityDto': [
    'Id',
    'CreationTime',
    'CreatorId',
    'ExtraProperties',
  ],
  'ExtensibleAuditedEntityDto': [
    'Id',
    'CreationTime',
    'CreatorId',
    'LastModificationTime',
    'LastModifierId',
    'ExtraProperties',
  ],
  'ExtensibleFullAuditedEntityDto': [
    'Id',
    'CreationTime',
    'CreatorId',
    'LastModificationTime',
    'LastModifierId',
    'IsDeleted',
    'DeleterId',
    'DeletionTime',
    'ExtraProperties',
  ],
  'ExtensibleObject': ['ExtraProperties'],
  'ExtensiblePagedAndSortedResultRequestDto': [
    'SkipCount',
    'MaxResultCount',
    'Sorting',
    'ExtraProperties',
  ],
  'PagedAndSortedResultRequestDto': ['SkipCount', 'MaxResultCount', 'Sorting'],
  'PagedResultRequestDto': ['SkipCount', 'MaxResultCount'],
  'LimitedResultRequestDto': ['MaxResultCount'],
};
