/// ABP Proxy Generator — Type Mapper.
///
/// Maps .NET type names to Dart type strings, tracking imports needed.
library;

import 'config.dart';
import 'naming_utils.dart';

/// An import entry tracked during type resolution.
class TypeImport {
  final String typeName;
  final bool isAbpShared;
  final bool isEnum;
  final String? fullName;

  const TypeImport({
    required this.typeName,
    required this.isAbpShared,
    required this.isEnum,
    this.fullName,
  });
}

/// Result of mapping a .NET type to Dart.
class MappedType {
  final String dartType;
  final List<TypeImport> imports;

  const MappedType({required this.dartType, required this.imports});
}

/// Map a .NET type to a Dart type.
///
/// [fullTypeName] — Full .NET type (e.g. `"Volo.Abp.Application.Dtos.PagedResultDto<MyApp.ProductDto>"`)
/// [typeSimple] — Simplified type hint from ABP (e.g. "string", "[ProductDto]")
/// [typesMap] — The `types` map from the ABP API definition
MappedType mapType(
  String? fullTypeName,
  String? typeSimple,
  Map<String, dynamic> typesMap,
) {
  final imports = <TypeImport>[];

  if (fullTypeName == null ||
      fullTypeName.isEmpty ||
      fullTypeName == 'System.Void') {
    return MappedType(dartType: 'void', imports: imports);
  }

  // Strip assembly version info (ABP can include full assembly-qualified names)
  fullTypeName = stripAssemblyVersion(fullTypeName);

  // Special case: byte[] → String (base64)
  if (fullTypeName == '[System.Byte]' ||
      fullTypeName == 'System.Byte[]' ||
      RegExp(r'System\.Collections\.Generic\.\w+<System\.Byte>')
          .hasMatch(fullTypeName)) {
    return MappedType(dartType: 'String', imports: imports);
  }

  // Check typeSimple shortcuts first
  if (typeSimple != null) {
    final simple = _mapTypeSimple(typeSimple, typesMap, imports);
    if (simple != null) return MappedType(dartType: simple, imports: imports);
  }

  // Check primitive map
  final primitive = primitiveTypeMap[fullTypeName];
  if (primitive != null) {
    return MappedType(dartType: primitive, imports: imports);
  }

  // Parse generic types
  final dartType = _resolveFullType(fullTypeName, typesMap, imports);
  return MappedType(dartType: dartType, imports: imports);
}

/// Try to resolve from ABP's typeSimple field.
String? _mapTypeSimple(
  String typeSimple,
  Map<String, dynamic> typesMap,
  List<TypeImport> imports,
) {
  // Direct primitive match
  final prim = primitiveTypeMap[typeSimple];
  if (prim != null) return prim;

  // If typeSimple contains full .NET namespaces (dots), fall through
  if (typeSimple.contains('.') && !typeSimple.startsWith('[')) {
    return null;
  }

  // ABP array notation: "[ProductDto]"
  if (typeSimple.startsWith('[') && typeSimple.endsWith(']')) {
    final inner = typeSimple.substring(1, typeSimple.length - 1);
    final innerPrimitive = primitiveTypeMap[inner];
    if (innerPrimitive != null) return 'List<$innerPrimitive>';

    if (inner.contains('.')) return null;

    final innerType = _resolveShortType(inner, typesMap, imports);
    return 'List<$innerType>';
  }

  // ABP nullable notation: "type?"
  if (typeSimple.endsWith('?')) {
    final inner = typeSimple.substring(0, typeSimple.length - 1);
    final innerPrimitive = primitiveTypeMap[inner];
    if (innerPrimitive != null) return '$innerPrimitive?';

    if (inner.contains('.')) return null;

    final innerType = _resolveShortType(inner, typesMap, imports);
    return '$innerType?';
  }

  // ABP generic notation in typeSimple: "PagedResultDto<ProductDto>"
  if (typeSimple.contains('<')) return null;

  return null;
}

/// Resolve a full .NET type name to Dart.
String _resolveFullType(
  String fullName,
  Map<String, dynamic> typesMap,
  List<TypeImport> imports,
) {
  if (fullName.isEmpty) return 'dynamic';

  // Handle trailing ? (nullable)
  if (fullName.endsWith('?')) {
    final inner = fullName.substring(0, fullName.length - 1);
    final innerDart = _resolveFullType(inner, typesMap, imports);
    return '$innerDart?';
  }

  // Handle C# array notation: "SomeType[]"
  if (fullName.endsWith('[]')) {
    final inner = fullName.substring(0, fullName.length - 2);
    final innerDart = _resolveFullType(inner, typesMap, imports);
    return 'List<$innerDart>';
  }

  // Handle ABP array notation: "[SomeType]"
  if (fullName.startsWith('[') && fullName.endsWith(']')) {
    final inner = fullName.substring(1, fullName.length - 1);
    final innerDart = _resolveFullType(inner, typesMap, imports);
    return 'List<$innerDart>';
  }

  // Handle ABP dictionary notation: "{KeyType:ValueType}"
  if (fullName.startsWith('{') && fullName.endsWith('}')) {
    final inner = fullName.substring(1, fullName.length - 1);
    final colonIdx = inner.indexOf(':');
    if (colonIdx > -1) {
      final keyDart =
          _resolveFullType(inner.substring(0, colonIdx), typesMap, imports);
      final valDart =
          _resolveFullType(inner.substring(colonIdx + 1), typesMap, imports);
      return 'Map<$keyDart, $valDart>';
    }
    return 'Map<String, dynamic>';
  }

  // Check primitive map
  final primitive = primitiveTypeMap[fullName];
  if (primitive != null) return primitive;

  // Parse generics
  final (:base, :args) = parseGenericType(fullName);

  // Check primitive for base (without generic args)
  final basePrimitive = primitiveTypeMap[base];
  if (basePrimitive != null && args.isEmpty) return basePrimitive;

  // Nullable<T>
  if (base == 'System.Nullable' && args.length == 1) {
    final innerDart = _resolveFullType(args[0], typesMap, imports);
    return '$innerDart?';
  }

  // Collection types -> List<T>
  if (collectionTypes.any((ct) => base == ct || base.startsWith('$ct`'))) {
    if (args.isNotEmpty) {
      final innerDart = _resolveFullType(args[0], typesMap, imports);
      return 'List<$innerDart>';
    }
    return 'List<dynamic>';
  }

  // Dictionary types -> Map<K, V>
  if (dictionaryTypes.any((dt) => base == dt || base.startsWith('$dt`'))) {
    if (args.length >= 2) {
      final keyDart = _resolveFullType(args[0], typesMap, imports);
      final valDart = _resolveFullType(args[1], typesMap, imports);
      return 'Map<$keyDart, $valDart>';
    }
    return 'Map<String, dynamic>';
  }

  // Unwrap types (ActionResult<T> -> T)
  if (unwrapTypes.any(
    (ut) => base == ut || base.startsWith('$ut<') || base.startsWith('$ut`'),
  )) {
    if (args.isNotEmpty) {
      return _resolveFullType(args[0], typesMap, imports);
    }
    return 'dynamic';
  }

  // Skip types
  if (skipTypes.any(
    (st) => base == st || base.startsWith('$st<') || base.startsWith('$st`'),
  )) {
    final primMapping = primitiveTypeMap[base];
    if (primMapping != null) return primMapping;
    return 'dynamic';
  }

  // Check if it's in the types map (user DTO or enum)
  final shortName = extractShortTypeName(base);

  // ABP shared types
  if (abpSharedTypes.contains(shortName)) {
    imports.add(
      TypeImport(typeName: shortName, isAbpShared: true, isEnum: false),
    );
    if (args.isNotEmpty) {
      final argTypes =
          args.map((a) => _resolveFullType(a, typesMap, imports)).toList();
      return '$shortName<${argTypes.join(', ')}>';
    }
    // NameValue requires a type argument; default to String when ABP omits it
    if (shortName == 'NameValue') {
      return 'NameValue<String>';
    }
    return shortName;
  }

  // Look up in typesMap by full name
  final typeInfo =
      _findInTypesMap(fullName, typesMap) ?? _findInTypesMap(base, typesMap);

  if (typeInfo != null) {
    final isEnum = typeInfo['isEnum'] == true;
    imports.add(
      TypeImport(
        typeName: shortName,
        isAbpShared: false,
        isEnum: isEnum,
        fullName: base,
      ),
    );

    if (args.isNotEmpty && !isEnum) {
      final argTypes =
          args.map((a) => _resolveFullType(a, typesMap, imports)).toList();
      return '$shortName<${argTypes.join(', ')}>';
    }
    return shortName;
  }

  // Unknown type
  return 'dynamic /* TODO: unknown type $fullName */';
}

/// Resolve a short type name (from typeSimple).
String _resolveShortType(
  String shortName,
  Map<String, dynamic> typesMap,
  List<TypeImport> imports,
) {
  // Check ABP shared types
  if (abpSharedTypes.contains(shortName)) {
    imports.add(
      TypeImport(typeName: shortName, isAbpShared: true, isEnum: false),
    );
    // NameValue requires a type argument; default to String when ABP omits it
    if (shortName == 'NameValue') {
      return 'NameValue<String>';
    }
    return shortName;
  }

  // Search typesMap for a type ending with this short name
  for (final entry in typesMap.entries) {
    if (extractShortTypeName(entry.key) == shortName) {
      final baseFullName = entry.key.replaceAll(RegExp(r'<.*>$'), '');
      if (primitiveTypeMap.containsKey(baseFullName)) {
        return primitiveTypeMap[baseFullName]!;
      }
      if (skipTypes.any(
        (st) =>
            baseFullName == st ||
            baseFullName.startsWith('$st`') ||
            baseFullName.startsWith('$st<'),
      )) {
        return 'dynamic';
      }

      final isEnum = (entry.value as Map<String, dynamic>)['isEnum'] == true;
      imports.add(
        TypeImport(
          typeName: shortName,
          isAbpShared: false,
          isEnum: isEnum,
          fullName: entry.key,
        ),
      );
      return shortName;
    }
  }

  return shortName;
}

/// Find a type in the types map, trying variations.
Map<String, dynamic>? _findInTypesMap(
  String typeName,
  Map<String, dynamic> typesMap,
) {
  // Direct match
  if (typesMap.containsKey(typeName)) {
    return typesMap[typeName] as Map<String, dynamic>;
  }

  // Try without generic arity suffix (e.g. `2)
  final withoutArity = typeName.replaceAll(RegExp(r'`\d+$'), '');
  if (typesMap.containsKey(withoutArity)) {
    return typesMap[withoutArity] as Map<String, dynamic>;
  }

  // Try matching by short name (last resort)
  final shortName = extractShortTypeName(typeName);
  for (final entry in typesMap.entries) {
    if (extractShortTypeName(entry.key) == shortName) {
      return entry.value as Map<String, dynamic>;
    }
  }

  return null;
}
