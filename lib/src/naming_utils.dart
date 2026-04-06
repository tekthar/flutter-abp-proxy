/// ABP Proxy Generator — Naming Utilities.
///
/// Functions for converting between PascalCase, camelCase, snake_case,
/// and kebab-case, plus .NET type name parsing utilities.
library;

/// Convert PascalCase to camelCase.
String pascalToCamel(String str) {
  if (str.isEmpty) return '';
  return str[0].toLowerCase() + str.substring(1);
}

/// Convert PascalCase or camelCase to snake_case.
String pascalToSnake(String str) {
  if (str.isEmpty) return '';
  return str
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m[1]}_${m[2]}',
      )
      .replaceAllMapped(
        RegExp(r'([A-Z])([A-Z][a-z])'),
        (m) => '${m[1]}_${m[2]}',
      )
      .toLowerCase();
}

/// Convert PascalCase or camelCase to kebab-case.
String pascalToKebab(String str) {
  if (str.isEmpty) return '';
  return str
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m[1]}-${m[2]}',
      )
      .replaceAllMapped(
        RegExp(r'([A-Z])([A-Z][a-z])'),
        (m) => '${m[1]}-${m[2]}',
      )
      .toLowerCase();
}

/// Strip the "Async" suffix from a method name (ABP convention).
String stripAsyncSuffix(String name) {
  if (name.isEmpty) return '';
  return name.endsWith('Async') ? name.substring(0, name.length - 5) : name;
}

/// Strip assembly-qualified version info from .NET type names.
///
/// e.g. `"List'1[[MyDto, MyApp.Contracts, Version=1.5.92.0, ...]]"` ->
///   `"List'1[[MyDto, MyApp.Contracts]]"`
///
/// ABP can include full assembly info; we only need the type name.
String stripAssemblyVersion(String typeName) {
  // Remove ", Version=..." segments and culture/token info within brackets
  return typeName
      .replaceAll(
        RegExp(r',\s*Version=[^,\]]+'),
        '',
      )
      .replaceAll(
        RegExp(r',\s*Culture=[^,\]]+'),
        '',
      )
      .replaceAll(
        RegExp(r',\s*PublicKeyToken=[^,\]]+'),
        '',
      );
}

/// Normalize nested class delimiters from C# (`+`) to Dart-safe names.
///
/// e.g. `"MyController+InnerClass"` -> `"MyControllerInnerClass"`
String normalizeNestedClassName(String name) {
  return name.replaceAll('+', '');
}

/// Extract the short type name from a full .NET type name.
///
/// Handles nested class `+` delimiters and strips assembly info.
///
/// e.g. "MyApp.Dto.ProductDto" -> "ProductDto"
/// e.g. `"MyApp.Dto.ProductDto<System.Guid>"` -> `"ProductDto"`
/// e.g. `"MyApp.MyController+InnerDto"` -> `"InnerDto"`
String extractShortTypeName(String fullName) {
  if (fullName.isEmpty) return '';
  // Strip assembly version info first
  var cleaned = stripAssemblyVersion(fullName);
  final angleIdx = cleaned.indexOf('<');
  final baseName = angleIdx > -1 ? cleaned.substring(0, angleIdx) : cleaned;
  // Handle nested class delimiter: take the part after the last + or .
  final lastPlus = baseName.lastIndexOf('+');
  final lastDot = baseName.lastIndexOf('.');
  final lastSep = lastPlus > lastDot ? lastPlus : lastDot;
  return lastSep > -1 ? baseName.substring(lastSep + 1) : baseName;
}

/// Extract the namespace from a full .NET type name.
///
/// e.g. "MyApp.Dto.ProductDto" -> "MyApp.Dto"
String extractNamespace(String fullName) {
  if (fullName.isEmpty) return '';
  final angleIdx = fullName.indexOf('<');
  final baseName = angleIdx > -1 ? fullName.substring(0, angleIdx) : fullName;
  final lastDot = baseName.lastIndexOf('.');
  return lastDot > -1 ? baseName.substring(0, lastDot) : '';
}

/// Parse a generic type string into its base type and type arguments.
///
/// e.g. `"PagedResultDto<ProductDto>"` -> `("PagedResultDto", ["ProductDto"])`
/// e.g. `"Dictionary<String,List<Int32>>"` -> `("Dictionary", ["String", "List<Int32>"])`
({String base, List<String> args}) parseGenericType(String typeStr) {
  if (typeStr.isEmpty) return (base: '', args: <String>[]);

  final angleIdx = typeStr.indexOf('<');
  if (angleIdx == -1) {
    return (base: typeStr.trim(), args: <String>[]);
  }

  final base = typeStr.substring(0, angleIdx).trim();
  final inner =
      typeStr.substring(angleIdx + 1, typeStr.lastIndexOf('>')).trim();

  final args = _splitGenericArgs(inner);
  return (base: base, args: args);
}

/// Split generic type arguments at top-level commas only.
List<String> _splitGenericArgs(String inner) {
  final args = <String>[];
  var depth = 0;
  final current = StringBuffer();

  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (ch == '<') {
      depth++;
      current.write(ch);
    } else if (ch == '>') {
      depth--;
      current.write(ch);
    } else if (ch == ',' && depth == 0) {
      args.add(current.toString().trim());
      current.clear();
    } else {
      current.write(ch);
    }
  }
  final remaining = current.toString().trim();
  if (remaining.isNotEmpty) {
    args.add(remaining);
  }
  return args;
}

/// Convert a type name to a snake_case file name.
///
/// e.g. "ProductDto" -> "product_dto"
String typeNameToFileName(String typeName) {
  return pascalToSnake(typeName);
}

/// Build a controller group name from the controller info.
///
/// Strips common suffixes like "Controller", "AppService".
String controllerToGroupName(String controllerName) {
  var name = controllerName;
  if (name.endsWith('Controller')) {
    name = name.substring(0, name.length - 'Controller'.length);
  } else if (name.endsWith('AppService')) {
    name = name.substring(0, name.length - 'AppService'.length);
  }
  return pascalToKebab(name);
}

/// Sanitize a string to be a valid Dart identifier.
String sanitizeIdentifier(String str) {
  if (str.isEmpty) return '_';
  var result = str.replaceAll(RegExp(r'[^a-zA-Z0-9_$]'), '_');
  if (RegExp(r'^[0-9]').hasMatch(result)) {
    result = '_$result';
  }
  return result;
}
