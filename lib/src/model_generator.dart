/// ABP Proxy Generator — Model Generator.
///
/// Generates Freezed model classes and enums from ABP API definition types.
library;

import 'package:path/path.dart' as p;

import 'config.dart';
import 'file_utils.dart';
import 'naming_utils.dart';
import 'type_mapper.dart';

/// Result of model generation.
class ModelGenerationResult {
  final List<({String filePath, bool written})> files;
  final Map<String, String> typeLocations;

  const ModelGenerationResult({
    required this.files,
    required this.typeLocations,
  });
}

/// Analyze types and determine which controller group each belongs to.
Map<String, _TypeOwnershipEntry> _analyzeTypeOwnership(
  Map<String, dynamic> apiDef,
) {
  final typesMap = apiDef['types'] as Map<String, dynamic>? ?? {};
  final modules = apiDef['modules'] as Map<String, dynamic>? ?? {};

  // Build a map: fullTypeName -> Set of controller group names that use it
  final typeUsage = <String, Set<String>>{};

  for (final module in modules.values) {
    final mod = module as Map<String, dynamic>;
    final rootPath = mod['rootPath'] as String? ?? 'default';
    final controllers = mod['controllers'] as Map<String, dynamic>? ?? {};

    for (final controller in controllers.values) {
      final ctrl = controller as Map<String, dynamic>;
      final controllerGroup = buildControllerGroup(ctrl, rootPath);
      final actions = ctrl['actions'] as Map<String, dynamic>? ?? {};

      for (final action in actions.values) {
        final act = action as Map<String, dynamic>;
        final visited = <String>{};

        for (final param in (act['parameters'] as List<dynamic>? ?? [])) {
          final p = param as Map<String, dynamic>;
          _collectTypeUsage(
            p['type'] as String?,
            typesMap,
            typeUsage,
            controllerGroup,
            visited,
          );
        }

        final returnValue = act['returnValue'] as Map<String, dynamic>?;
        if (returnValue != null) {
          _collectTypeUsage(
            returnValue['type'] as String?,
            typesMap,
            typeUsage,
            controllerGroup,
            visited,
          );
        }
      }
    }
  }

  // Assign each type to a controller group or shared
  final result = <String, _TypeOwnershipEntry>{};
  for (final entry in typesMap.entries) {
    final fullName = entry.key;
    final typeInfo = entry.value as Map<String, dynamic>;
    final shortName = extractShortTypeName(fullName);

    if (abpSharedTypes.contains(shortName)) continue;
    if (primitiveTypeMap.containsKey(fullName)) continue;
    if (skipTypes.any(
      (st) =>
          fullName == st ||
          fullName.startsWith('$st`') ||
          fullName.startsWith('$st<'),
    )) {
      continue;
    }

    final groups = typeUsage[fullName];
    String? controllerGroup;
    if (groups != null && groups.length == 1) {
      controllerGroup = groups.first;
    }

    result[fullName] = _TypeOwnershipEntry(
      typeInfo: typeInfo,
      fullName: fullName,
      shortName: shortName,
      controllerGroup: controllerGroup,
    );
  }

  return result;
}

/// Recursively collect type usage for a given full type name.
void _collectTypeUsage(
  String? fullTypeName,
  Map<String, dynamic> typesMap,
  Map<String, Set<String>> typeUsage,
  String controllerGroup,
  Set<String> visited,
) {
  if (fullTypeName == null || fullTypeName.isEmpty) return;
  if (visited.contains(fullTypeName)) return;
  visited.add(fullTypeName);

  final (:base, :args) = parseGenericType(fullTypeName);
  visited.add(base);

  final typeInfo =
      (typesMap[fullTypeName] ?? typesMap[base]) as Map<String, dynamic>?;
  if (typeInfo != null) {
    final usedName = typesMap.containsKey(fullTypeName) ? fullTypeName : base;
    typeUsage.putIfAbsent(usedName, () => <String>{}).add(controllerGroup);

    final properties = typeInfo['properties'] as List<dynamic>? ?? [];
    for (final prop in properties) {
      final p = prop as Map<String, dynamic>;
      _collectTypeUsage(
        p['type'] as String?,
        typesMap,
        typeUsage,
        controllerGroup,
        visited,
      );
    }

    final baseType = typeInfo['baseType'] as String?;
    if (baseType != null) {
      _collectTypeUsage(
        baseType,
        typesMap,
        typeUsage,
        controllerGroup,
        visited,
      );
    }
  }

  for (final arg in args) {
    _collectTypeUsage(arg, typesMap, typeUsage, controllerGroup, visited);
  }
}

/// Build controller group path from controller info.
String buildControllerGroup(Map<String, dynamic> controller, String rootPath) {
  final kebabRoot = pascalToKebab(rootPath);
  final rawGroup = (controller['controllerGroupName'] ??
      controller['controllerName'] ??
      'default') as String;
  final groupName = pascalToKebab(rawGroup.replaceAll(RegExp(r'\s+'), '-'));
  return '$kebabRoot/$groupName';
}

/// Options for model generation.
class ModelGenerationOptions {
  final bool dryRun;
  final String sourceUrl;
  final bool unknownEnumValue;

  const ModelGenerationOptions({
    this.dryRun = false,
    this.sourceUrl = '',
    this.unknownEnumValue = true,
  });
}

/// Generate all model files.
ModelGenerationResult generateModels(
  Map<String, dynamic> apiDef,
  String outputDir, {
  bool dryRun = false,
  String sourceUrl = '',
  bool unknownEnumValue = true,
}) {
  final typesMap = apiDef['types'] as Map<String, dynamic>? ?? {};
  final ownership = _analyzeTypeOwnership(apiDef);
  final files = <({String filePath, bool written})>[];
  final typeLocations = <String, String>{};

  // 1. Generate shared ABP types
  final abpTypesContent = _generateAbpTypes(sourceUrl);
  final abpTypesPath = p.join(outputDir, 'shared', 'models', 'abp_types.dart');
  files.add(writeGeneratedFile(abpTypesPath, abpTypesContent, dryRun: dryRun));

  for (final typeName in abpSharedTypes) {
    typeLocations[typeName] = './shared/models/abp_types';
  }

  // 1b. Generate ABP error response model
  final errorModelContent = _generateAbpErrorModel(sourceUrl);
  final errorModelPath =
      p.join(outputDir, 'shared', 'models', 'abp_error.dart');
  files.add(
    writeGeneratedFile(errorModelPath, errorModelContent, dryRun: dryRun),
  );
  typeLocations['RemoteServiceErrorResponse'] = './shared/models/abp_error';
  typeLocations['RemoteServiceErrorInfo'] = './shared/models/abp_error';
  typeLocations['RemoteServiceValidationErrorInfo'] =
      './shared/models/abp_error';

  // 2. First pass: register ALL type locations
  final typeEntries = <_TypeEntry>[];
  for (final entry in ownership.entries) {
    final fullName = entry.key;
    final ownerEntry = entry.value;
    final shortName = ownerEntry.shortName;
    final controllerGroup = ownerEntry.controllerGroup;

    String relDir;
    if (controllerGroup != null) {
      relDir = p.posix.join(controllerGroup, 'models');
    } else {
      relDir = p.posix.join('shared', 'models');
    }

    final fileName = typeNameToFileName(shortName);
    final filePath = p.join(outputDir, relDir, '$fileName.dart');

    typeLocations[shortName] = './$relDir/$fileName';
    typeLocations[fullName] = './$relDir/$fileName';

    typeEntries.add(
      _TypeEntry(
        fullName: fullName,
        entry: ownerEntry,
        relDir: relDir,
        fileName: fileName,
        filePath: filePath,
      ),
    );
  }

  // 3. Second pass: generate files
  for (final te in typeEntries) {
    final typeInfo = te.entry.typeInfo;
    final shortName = te.entry.shortName;

    if (typeInfo['isEnum'] == true) {
      final content = _generateEnum(
        shortName,
        typeInfo,
        sourceUrl,
        unknownEnumValue: unknownEnumValue,
      );
      files.add(writeGeneratedFile(te.filePath, content, dryRun: dryRun));
    } else {
      final content = _generateFreezedClass(
        te.fullName,
        shortName,
        typeInfo,
        typesMap,
        typeLocations,
        te.relDir,
        sourceUrl,
      );
      files.add(writeGeneratedFile(te.filePath, content, dryRun: dryRun));
    }
  }

  return ModelGenerationResult(files: files, typeLocations: typeLocations);
}

/// Generate the ABP shared types file.
String _generateAbpTypes(String sourceUrl) {
  return '''// GENERATED FILE — DO NOT EDIT BY HAND
// Source: $sourceUrl
// Generator: flutter_abp_proxy

import 'package:json_annotation/json_annotation.dart';

// ---- Paging & List result wrappers ----

class ListResultDto<T> {
  final List<T> items;

  const ListResultDto({required this.items});

  factory ListResultDto.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return ListResultDto<T>(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => fromJsonT(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    return {'items': items.map(toJsonT).toList()};
  }
}

class PagedResultDto<T> extends ListResultDto<T> {
  final int totalCount;

  const PagedResultDto({required super.items, required this.totalCount});

  factory PagedResultDto.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return PagedResultDto<T>(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => fromJsonT(e))
              .toList() ??
          [],
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    return {
      ...super.toJson(toJsonT),
      'totalCount': totalCount,
    };
  }
}

// ---- Request DTOs ----

class PagedResultRequestDto {
  final int? skipCount;
  final int? maxResultCount;

  const PagedResultRequestDto({this.skipCount, this.maxResultCount});

  Map<String, dynamic> toJson() => {
        if (skipCount != null) 'skipCount': skipCount,
        if (maxResultCount != null) 'maxResultCount': maxResultCount,
      };
}

class LimitedResultRequestDto {
  final int? maxResultCount;

  const LimitedResultRequestDto({this.maxResultCount});

  Map<String, dynamic> toJson() => {
        if (maxResultCount != null) 'maxResultCount': maxResultCount,
      };
}

class PagedAndSortedResultRequestDto extends PagedResultRequestDto {
  final String? sorting;

  const PagedAndSortedResultRequestDto({
    super.skipCount,
    super.maxResultCount,
    this.sorting,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        if (sorting != null) 'sorting': sorting,
      };
}

// ---- Entity DTOs ----

class EntityDto<TKey> {
  final TKey id;

  const EntityDto({required this.id});
}

class CreationAuditedEntityDto<TKey> extends EntityDto<TKey> {
  final DateTime? creationTime;
  final String? creatorId;

  const CreationAuditedEntityDto({
    required super.id,
    this.creationTime,
    this.creatorId,
  });
}

class AuditedEntityDto<TKey> extends CreationAuditedEntityDto<TKey> {
  final DateTime? lastModificationTime;
  final String? lastModifierId;

  const AuditedEntityDto({
    required super.id,
    super.creationTime,
    super.creatorId,
    this.lastModificationTime,
    this.lastModifierId,
  });
}

class FullAuditedEntityDto<TKey> extends AuditedEntityDto<TKey> {
  final bool isDeleted;
  final String? deleterId;
  final DateTime? deletionTime;

  const FullAuditedEntityDto({
    required super.id,
    super.creationTime,
    super.creatorId,
    super.lastModificationTime,
    super.lastModifierId,
    this.isDeleted = false,
    this.deleterId,
    this.deletionTime,
  });
}

// ---- Audited with user variants ----

class CreationAuditedEntityWithUserDto<TKey>
    extends CreationAuditedEntityDto<TKey> {
  final dynamic creator;

  const CreationAuditedEntityWithUserDto({
    required super.id,
    super.creationTime,
    super.creatorId,
    this.creator,
  });
}

class AuditedEntityWithUserDto<TKey> extends AuditedEntityDto<TKey> {
  final dynamic creator;
  final dynamic lastModifier;

  const AuditedEntityWithUserDto({
    required super.id,
    super.creationTime,
    super.creatorId,
    super.lastModificationTime,
    super.lastModifierId,
    this.creator,
    this.lastModifier,
  });
}

// ---- Extensible variants ----

class ExtensibleObject {
  final Map<String, dynamic> extraProperties;

  const ExtensibleObject({this.extraProperties = const {}});
}

class ExtensibleEntityDto<TKey> extends EntityDto<TKey> {
  final Map<String, dynamic> extraProperties;

  const ExtensibleEntityDto({
    required super.id,
    this.extraProperties = const {},
  });
}

class ExtensibleCreationAuditedEntityDto<TKey>
    extends CreationAuditedEntityDto<TKey> {
  final Map<String, dynamic> extraProperties;

  const ExtensibleCreationAuditedEntityDto({
    required super.id,
    super.creationTime,
    super.creatorId,
    this.extraProperties = const {},
  });
}

class ExtensibleAuditedEntityDto<TKey> extends AuditedEntityDto<TKey> {
  final Map<String, dynamic> extraProperties;

  const ExtensibleAuditedEntityDto({
    required super.id,
    super.creationTime,
    super.creatorId,
    super.lastModificationTime,
    super.lastModifierId,
    this.extraProperties = const {},
  });
}

class ExtensibleFullAuditedEntityDto<TKey> extends FullAuditedEntityDto<TKey> {
  final Map<String, dynamic> extraProperties;

  const ExtensibleFullAuditedEntityDto({
    required super.id,
    super.creationTime,
    super.creatorId,
    super.lastModificationTime,
    super.lastModifierId,
    super.isDeleted,
    super.deleterId,
    super.deletionTime,
    this.extraProperties = const {},
  });
}

class ExtensiblePagedAndSortedResultRequestDto
    extends PagedAndSortedResultRequestDto {
  final Map<String, dynamic> extraProperties;

  const ExtensiblePagedAndSortedResultRequestDto({
    super.skipCount,
    super.maxResultCount,
    super.sorting,
    this.extraProperties = const {},
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'extraProperties': extraProperties,
      };
}

// ---- Common utility types ----

class NameValue<T> {
  final String? name;
  final T? value;

  const NameValue({this.name, this.value});

  factory NameValue.fromJson(Map<String, dynamic> json) {
    return NameValue<T>(
      name: json['name'] as String?,
      value: json['value'] as T?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
    };
  }
}
''';
}

/// Generate a Freezed model class.
String _generateFreezedClass(
  String fullName,
  String shortName,
  Map<String, dynamic> typeInfo,
  Map<String, dynamic> typesMap,
  Map<String, String> typeLocations,
  String currentRelDir,
  String sourceUrl,
) {
  final buf = StringBuffer();
  final fileName = typeNameToFileName(shortName);

  // Collect properties, imports, generic params
  final genericParams =
      (typeInfo['genericArguments'] as List<dynamic>?)?.cast<String>() ?? [];

  // Collect inherited property names
  final inheritedProps = <String>{};
  final baseTypeStr = typeInfo['baseType'] as String?;
  if (baseTypeStr != null) {
    _collectInheritedPropertyNames(baseTypeStr, typesMap, inheritedProps, {});
  }

  // Build properties
  final properties = <_PropertyInfo>[];
  final importMap = <String, Set<String>>{}; // path -> type names

  for (final prop in (typeInfo['properties'] as List<dynamic>? ?? [])) {
    final p = prop as Map<String, dynamic>;
    final propName = p['name'] as String;
    if (inheritedProps.contains(propName)) continue;

    final mapped = mapType(
      p['type'] as String?,
      p['typeSimple'] as String?,
      typesMap,
    );

    var dartType = mapped.dartType;

    // Check if type is a generic parameter of this class
    final typeSimple = p['typeSimple'] as String?;
    final propType = p['type'] as String?;
    if (genericParams.contains(typeSimple) ||
        genericParams.contains(propType)) {
      dartType = typeSimple ?? propType ?? dartType;
    }

    final isRequired = p['isRequired'] == true;

    var dartName = pascalToCamel(propName);
    // Escape Dart reserved words for property names
    if (dartReservedWords.contains(dartName)) {
      dartName = '$dartName\$';
    }

    properties.add(
      _PropertyInfo(
        name: dartName,
        jsonName: propName,
        type: dartType,
        isRequired: isRequired,
      ),
    );

    for (final imp in mapped.imports) {
      if (imp.typeName != shortName) {
        _addImport(
          importMap,
          imp.typeName,
          typeLocations,
          currentRelDir,
          selfFileName: typeNameToFileName(shortName),
        );
      }
    }
  }

  // Header
  buf.writeln('// GENERATED FILE — DO NOT EDIT BY HAND');
  buf.writeln('// Source: $sourceUrl');
  buf.writeln('// Generator: flutter_abp_proxy');
  buf.writeln();
  buf.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");

  // Model imports
  for (final entry in importMap.entries) {
    buf.writeln("import '${entry.key}.dart';");
  }

  buf.writeln();
  buf.writeln("part '$fileName.freezed.dart';");
  buf.writeln("part '$fileName.g.dart';");
  buf.writeln();

  // Class definition
  final genericSuffix =
      genericParams.isNotEmpty ? '<${genericParams.join(', ')}>' : '';

  buf.writeln('@freezed');
  buf.writeln(
    'abstract class $shortName$genericSuffix with _\$$shortName$genericSuffix {',
  );
  if (properties.isEmpty) {
    buf.writeln('  const factory $shortName$genericSuffix() = _$shortName;');
  } else {
    buf.writeln('  const factory $shortName$genericSuffix({');

    for (final prop in properties) {
      // Add @JsonKey if the Dart name differs from the JSON name
      final dartName = prop.name;
      final jsonName = prop.jsonName;
      if (dartName != pascalToCamel(jsonName)) {
        buf.writeln("    @JsonKey(name: '$jsonName')");
      }

      if (prop.isRequired && !prop.type.endsWith('?')) {
        buf.writeln('    required ${prop.type} ${prop.name},');
      } else {
        final nullableType =
            prop.type.endsWith('?') ? prop.type : '${prop.type}?';
        buf.writeln('    $nullableType ${prop.name},');
      }
    }

    buf.writeln('  }) = _$shortName;');
  }
  buf.writeln();

  if (genericParams.isEmpty) {
    buf.writeln(
      '  factory $shortName.fromJson(Map<String, dynamic> json) =>',
    );
    buf.writeln('      _\$${shortName}FromJson(json);');
  }

  buf.writeln('}');

  return buf.toString();
}

/// Generate an enum with optional unknown fallback value.
String _generateEnum(
  String name,
  Map<String, dynamic> typeInfo,
  String sourceUrl, {
  bool unknownEnumValue = true,
}) {
  final buf = StringBuffer();
  final enumNames =
      (typeInfo['enumNames'] as List<dynamic>?)?.cast<String>() ?? [];
  final enumValues =
      (typeInfo['enumValues'] as List<dynamic>?)?.cast<int?>() ?? [];

  buf.writeln('// GENERATED FILE — DO NOT EDIT BY HAND');
  buf.writeln('// Source: $sourceUrl');
  buf.writeln('// Generator: flutter_abp_proxy');
  buf.writeln();
  buf.writeln("import 'package:json_annotation/json_annotation.dart';");
  buf.writeln();

  // Compute the unknown sentinel value (one below min or -999)
  final allValues = <int>[];
  for (var i = 0; i < enumNames.length; i++) {
    allValues.add(i < enumValues.length ? enumValues[i] ?? i : i);
  }
  final unknownSentinel =
      allValues.isEmpty ? -1 : (allValues.reduce((a, b) => a < b ? a : b) - 1);

  buf.writeln('enum $name {');

  // Unknown fallback member first (so it's the default)
  if (unknownEnumValue) {
    buf.writeln('  @JsonValue($unknownSentinel)');
    buf.writeln('  unknown,');
    buf.writeln();
  }

  for (var i = 0; i < enumNames.length; i++) {
    var memberName = pascalToCamel(enumNames[i]);

    // Escape Dart reserved words
    if (dartReservedWords.contains(memberName)) {
      memberName = '$memberName\$';
    }

    final value = allValues[i];
    buf.writeln('  @JsonValue($value)');
    buf.write('  $memberName');
    if (i < enumNames.length - 1) {
      buf.writeln(',');
    } else {
      buf.writeln(';');
    }
  }

  buf.writeln('}');

  // Generate companion options constant for UI dropdowns
  buf.writeln();
  buf.writeln(
      '/// Ready-to-use options list for [$name] (useful for dropdowns).');
  buf.writeln(
      'const ${pascalToCamel(name)}Options = <({$name value, String label})>[');
  for (var i = 0; i < enumNames.length; i++) {
    var memberName = pascalToCamel(enumNames[i]);
    if (dartReservedWords.contains(memberName)) {
      memberName = '$memberName\$';
    }
    // Label is the original PascalCase name with spaces inserted
    final label = enumNames[i]
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    buf.writeln("  (value: $name.$memberName, label: '$label'),");
  }
  buf.writeln('];');

  return buf.toString();
}

/// Recursively collect property names from base types.
void _collectInheritedPropertyNames(
  String baseTypeStr,
  Map<String, dynamic> typesMap,
  Set<String> propNames,
  Set<String> visited,
) {
  if (visited.contains(baseTypeStr)) return;
  visited.add(baseTypeStr);

  final (:base, args: _) = parseGenericType(baseTypeStr);

  final typeInfo =
      (typesMap[baseTypeStr] ?? typesMap[base]) as Map<String, dynamic>?;
  if (typeInfo != null) {
    for (final prop in (typeInfo['properties'] as List<dynamic>? ?? [])) {
      final p = prop as Map<String, dynamic>;
      propNames.add(p['name'] as String);
    }
    final nextBase = typeInfo['baseType'] as String?;
    if (nextBase != null) {
      _collectInheritedPropertyNames(nextBase, typesMap, propNames, visited);
    }
  }

  final shortName = extractShortTypeName(base);
  final abpProps = abpInheritedProps[shortName];
  if (abpProps != null) {
    propNames.addAll(abpProps);
  }
}

/// Add an import entry, resolving the relative path.
///
/// [selfFileName] prevents self-imports (ABP bug #25080).
void _addImport(
  Map<String, Set<String>> importMap,
  String typeName,
  Map<String, String> typeLocations,
  String currentRelDir, {
  String? selfFileName,
}) {
  final location = typeLocations[typeName];
  if (location == null) return;

  final fromDir = currentRelDir.replaceAll('\\', '/');
  final toFile = location.replaceFirst(RegExp(r'^\./'), '');

  // Self-import prevention: skip if the resolved file is the current file
  if (selfFileName != null) {
    final targetFile = toFile.split('/').last;
    if (targetFile == selfFileName) return;
  }

  final fromParts = fromDir.split('/');
  final toParts = toFile.split('/');

  var common = 0;
  while (common < fromParts.length &&
      common < toParts.length &&
      fromParts[common] == toParts[common]) {
    common++;
  }

  final upCount = fromParts.length - common;
  String relativePath;
  if (upCount == 0) {
    relativePath = './${toParts.sublist(common).join('/')}';
  } else {
    relativePath = '${'../' * upCount}${toParts.sublist(common).join('/')}';
  }

  importMap.putIfAbsent(relativePath, () => <String>{}).add(typeName);
}

/// Generate the ABP structured error response model.
String _generateAbpErrorModel(String sourceUrl) {
  return '''// GENERATED FILE — DO NOT EDIT BY HAND
// Source: $sourceUrl
// Generator: flutter_abp_proxy

import 'package:freezed_annotation/freezed_annotation.dart';

part 'abp_error.freezed.dart';
part 'abp_error.g.dart';

/// ABP structured error response envelope.
@freezed
abstract class RemoteServiceErrorResponse with _\$RemoteServiceErrorResponse {
  const factory RemoteServiceErrorResponse({
    RemoteServiceErrorInfo? error,
  }) = _RemoteServiceErrorResponse;

  factory RemoteServiceErrorResponse.fromJson(Map<String, dynamic> json) =>
      _\$RemoteServiceErrorResponseFromJson(json);
}

/// ABP error info with code, message, details, and validation errors.
@freezed
abstract class RemoteServiceErrorInfo with _\$RemoteServiceErrorInfo {
  const factory RemoteServiceErrorInfo({
    String? code,
    String? message,
    String? details,
    Map<String, dynamic>? data,
    List<RemoteServiceValidationErrorInfo>? validationErrors,
  }) = _RemoteServiceErrorInfo;

  factory RemoteServiceErrorInfo.fromJson(Map<String, dynamic> json) =>
      _\$RemoteServiceErrorInfoFromJson(json);
}

/// ABP validation error entry.
@freezed
abstract class RemoteServiceValidationErrorInfo
    with _\$RemoteServiceValidationErrorInfo {
  const factory RemoteServiceValidationErrorInfo({
    String? message,
    List<String>? members,
  }) = _RemoteServiceValidationErrorInfo;

  factory RemoteServiceValidationErrorInfo.fromJson(
    Map<String, dynamic> json,
  ) => _\$RemoteServiceValidationErrorInfoFromJson(json);
}
''';
}

/// Check if a DTO type contains IRemoteStreamContent or IFormFile properties
/// (recursively), which means the method should use multipart encoding.
bool dtoContainsStreamContent(
  String? typeName,
  Map<String, dynamic> typesMap, [
  Set<String>? visited,
]) {
  if (typeName == null || typeName.isEmpty) return false;
  visited ??= <String>{};
  if (visited.contains(typeName)) return false;
  visited.add(typeName);

  // Check if the type itself is a stream content type
  for (final sct in streamContentTypes) {
    if (typeName == sct || typeName.contains(sct)) return true;
  }

  // Look up in types map and check properties recursively
  final (:base, args: _) = parseGenericType(typeName);
  final typeInfo =
      (typesMap[typeName] ?? typesMap[base]) as Map<String, dynamic>?;
  if (typeInfo == null) return false;

  for (final prop in (typeInfo['properties'] as List<dynamic>? ?? [])) {
    final p = prop as Map<String, dynamic>;
    final propType = p['type'] as String?;
    if (propType != null &&
        dtoContainsStreamContent(propType, typesMap, visited)) {
      return true;
    }
  }

  return false;
}

// --- Private data classes ---

class _TypeOwnershipEntry {
  final Map<String, dynamic> typeInfo;
  final String fullName;
  final String shortName;
  final String? controllerGroup;

  const _TypeOwnershipEntry({
    required this.typeInfo,
    required this.fullName,
    required this.shortName,
    required this.controllerGroup,
  });
}

class _TypeEntry {
  final String fullName;
  final _TypeOwnershipEntry entry;
  final String relDir;
  final String fileName;
  final String filePath;

  const _TypeEntry({
    required this.fullName,
    required this.entry,
    required this.relDir,
    required this.fileName,
    required this.filePath,
  });
}

class _PropertyInfo {
  final String name;
  final String jsonName;
  final String type;
  final bool isRequired;

  const _PropertyInfo({
    required this.name,
    required this.jsonName,
    required this.type,
    required this.isRequired,
  });
}
