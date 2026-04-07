/// ABP Proxy Generator — Service Generator.
///
/// Generates Retrofit abstract service classes from ABP API definition controllers.
library;

import 'package:path/path.dart' as p;

import 'config.dart';
import 'file_utils.dart';
import 'model_generator.dart'
    show buildControllerGroup, dtoContainsStreamContent;
import 'naming_utils.dart';
import 'type_mapper.dart';

/// Result of service generation.
class ServiceGenerationResult {
  final List<({String filePath, bool written})> files;

  const ServiceGenerationResult({required this.files});
}

/// Generate all service files from the API definition.
/// Service type filter for generation.
enum ServiceTypeFilter {
  /// Only application services (default — user-facing APIs).
  application,

  /// Only integration services (internal ABP framework APIs).
  integration,

  /// All services.
  all,
}

/// Generate all service files from the API definition.
ServiceGenerationResult generateServices(
  Map<String, dynamic> apiDef,
  String outputDir,
  Map<String, String> typeLocations, {
  bool dryRun = false,
  String sourceUrl = '',
  String? moduleFilter,
  ServiceTypeFilter serviceType = ServiceTypeFilter.application,
}) {
  final typesMap = apiDef['types'] as Map<String, dynamic>? ?? {};
  final modules = apiDef['modules'] as Map<String, dynamic>? ?? {};
  final files = <({String filePath, bool written})>[];

  for (final module in modules.values) {
    final mod = module as Map<String, dynamic>;
    final rootPath = mod['rootPath'] as String? ?? 'default';
    final kebabRoot = pascalToKebab(rootPath);

    if (moduleFilter != null &&
        rootPath != moduleFilter &&
        kebabRoot != moduleFilter) {
      continue;
    }

    final controllers = mod['controllers'] as Map<String, dynamic>? ?? {};

    for (final controller in controllers.values) {
      final ctrl = controller as Map<String, dynamic>;

      // Service type filtering: ABP marks integration services with
      // isIntegrationService flag or by interface naming convention
      if (serviceType != ServiceTypeFilter.all) {
        final isIntegration = ctrl['isIntegrationService'] == true ||
            _looksLikeIntegrationService(ctrl);
        if (serviceType == ServiceTypeFilter.application && isIntegration) {
          continue;
        }
        if (serviceType == ServiceTypeFilter.integration && !isIntegration) {
          continue;
        }
      }

      final controllerGroup = buildControllerGroup(ctrl, rootPath);
      final rawGroup = (ctrl['controllerGroupName'] ??
          ctrl['controllerName'] ??
          'default') as String;
      final groupName = pascalToKebab(rawGroup.replaceAll(RegExp(r'\s+'), '-'));
      final className =
          '${rawGroup.replaceAll(RegExp(r'\s+'), '')}ProxyService';

      final actions = ctrl['actions'] as Map<String, dynamic>? ?? {};
      final methods = <_MethodData>[];
      final serviceImportMap = <String, Set<String>>{};
      final seenMethodNames = <String>{};

      for (final action in actions.values) {
        final act = action as Map<String, dynamic>;
        final methodData = _buildMethodData(
          act,
          typesMap,
          typeLocations,
          controllerGroup,
          serviceImportMap,
        );

        // Deduplicate methods with the same name (ABP can produce
        // duplicate uniqueName values when multiple routes exist)
        var methodName = methodData.name;
        if (seenMethodNames.contains(methodName)) {
          var suffix = 2;
          while (seenMethodNames.contains('$methodName$suffix')) {
            suffix++;
          }
          methodName = '$methodName$suffix';
          methods.add(methodData.copyWithName(methodName));
        } else {
          methods.add(methodData);
        }
        seenMethodNames.add(methodName);
      }

      // Build the service file content
      final content = _renderService(
        className: className,
        methods: methods,
        importMap: serviceImportMap,
        sourceUrl: sourceUrl,
        groupName: groupName,
      );

      final servicePath =
          p.join(outputDir, controllerGroup, '${groupName}_service.dart');
      files.add(writeGeneratedFile(servicePath, content, dryRun: dryRun));
    }
  }

  return ServiceGenerationResult(files: files);
}

/// Render a Retrofit service file.
String _renderService({
  required String className,
  required List<_MethodData> methods,
  required Map<String, Set<String>> importMap,
  required String sourceUrl,
  required String groupName,
}) {
  final buf = StringBuffer();

  buf.writeln('// GENERATED FILE — DO NOT EDIT BY HAND');
  buf.writeln('// Source: $sourceUrl');
  buf.writeln('// Generator: flutter_abp_proxy');
  buf.writeln();
  buf.writeln("import 'package:dio/dio.dart';");
  buf.writeln("import 'package:retrofit/retrofit.dart';");

  // Model imports
  final importPaths = importMap.keys.toList()..sort();
  for (final importPath in importPaths) {
    buf.writeln("import '$importPath.dart';");
  }

  buf.writeln();
  buf.writeln("part '${groupName}_service.g.dart';");
  buf.writeln();
  buf.writeln('@RestApi()');
  buf.writeln('abstract class $className {');
  buf.writeln(
    '  factory $className(Dio dio, {String baseUrl}) = _$className;',
  );

  for (final method in methods) {
    buf.writeln();

    // Doc comment
    buf.writeln('  /// ${method.httpMethod} ${method.urlTemplate}');
    if (method.summary.isNotEmpty) {
      buf.writeln('  /// ${method.summary}');
    }

    // Multipart annotation (explicit form params or stream content in body DTO)
    if ((method.formDataParams != null && method.formDataParams!.isNotEmpty) ||
        method.hasStreamContentInBody) {
      buf.writeln('  @MultiPart()');
    }

    // API version as query parameter (when not embedded in URL path)
    if (method.apiVersion != null) {
      buf.writeln(
        "  @Headers(<String, dynamic>{'api-version': '${method.apiVersion}'})",
      );
    }

    // HTTP method annotation
    buf.writeln(
      "  @${method.httpMethod}('${method.urlTemplate}')",
    );

    // Method signature
    buf.write('  Future<${method.returnType}> ${method.name}(');

    if (method.allParams.isNotEmpty) {
      buf.writeln();
      for (var i = 0; i < method.allParams.length; i++) {
        final param = method.allParams[i];
        final annotation = _buildParamAnnotation(param);
        final trailing = i < method.allParams.length - 1 ? ',' : ',';

        if (param.isOptional) {
          final nullableType =
              param.type.endsWith('?') ? param.type : '${param.type}?';
          buf.writeln(
              '    $annotation $nullableType ${param.varName}$trailing');
        } else {
          buf.writeln(
            '    $annotation ${param.type} ${param.varName}$trailing',
          );
        }
      }
      buf.writeln('  );');
    } else {
      buf.writeln(');');
    }
  }

  buf.writeln('}');

  return buf.toString();
}

/// Build the Retrofit parameter annotation.
String _buildParamAnnotation(_ParamInfo param) {
  switch (param.binding) {
    case 'Path':
      return "@Path('${param.apiName}')";
    case 'Query':
      return "@Query('${param.apiName}')";
    case 'Body':
      return '@Body()';
    case 'Form':
      return "@Part(name: '${param.apiName}')";
    default:
      return "@Query('${param.apiName}')";
  }
}

/// Build method data for a single action.
_MethodData _buildMethodData(
  Map<String, dynamic> action,
  Map<String, dynamic> typesMap,
  Map<String, String> typeLocations,
  String controllerGroup,
  Map<String, Set<String>> importMap,
) {
  final httpMethod = (action['httpMethod'] as String? ?? 'GET').toUpperCase();
  final methodName = pascalToCamel(
    stripAsyncSuffix(
      (action['uniqueName'] ?? action['name'] ?? 'unknown') as String,
    ),
  );
  var urlTemplate = action['url'] as String? ?? '';

  // API versioning: detect supported versions and inject into URL or query
  String? apiVersion;
  final supportedVersions = action['supportedVersions'] as List<dynamic>?;
  if (supportedVersions != null && supportedVersions.isNotEmpty) {
    // Use the latest supported version
    apiVersion = supportedVersions.last.toString();

    // If the URL contains {version} or {api-version} placeholder, fill it in
    if (urlTemplate.contains('{version}') ||
        urlTemplate.contains('{api-version}')) {
      urlTemplate = urlTemplate
          .replaceAll('{version}', apiVersion)
          .replaceAll('{api-version}', apiVersion);
      apiVersion = null; // Already in the URL path, no query param needed
    }
  }

  final pathParams = <_ParamInfo>[];
  final queryParams = <_ParamInfo>[];
  final bodyParams = <_ParamInfo>[];
  final formParams = <_ParamInfo>[];
  final allParams = <_ParamInfo>[];

  for (final param in (action['parameters'] as List<dynamic>? ?? [])) {
    final p = param as Map<String, dynamic>;
    final binding = _resolveBindingSource(p, httpMethod);
    final mapped = mapType(
      p['type'] as String?,
      p['typeSimple'] as String?,
      typesMap,
    );
    final varName = sanitizeIdentifier(pascalToCamel(p['name'] as String));
    final isOptional = p['isRequired'] != true && p['defaultValue'] == null;

    final paramInfo = _ParamInfo(
      name: p['name'] as String,
      varName: varName,
      apiName: (p['nameOnQuery'] ?? p['name']) as String,
      type: mapped.dartType,
      isOptional: isOptional,
      isArray: mapped.dartType.startsWith('List<'),
      binding: binding,
    );

    for (final imp in mapped.imports) {
      _addServiceImport(
        importMap,
        imp.typeName,
        typeLocations,
        controllerGroup,
      );
    }

    switch (binding) {
      case 'Path':
        pathParams.add(paramInfo);
      case 'Query':
        queryParams.add(paramInfo);
      case 'Body':
        bodyParams.add(paramInfo);
      case 'Form':
        formParams.add(paramInfo);
    }
    allParams.add(paramInfo);
  }

  // Sort: required params first, then optional
  allParams.sort((a, b) {
    if (a.isOptional == b.isOptional) return 0;
    return a.isOptional ? 1 : -1;
  });

  // Resolve return type
  var returnType = 'void';
  final returnValue = action['returnValue'] as Map<String, dynamic>?;
  if (returnValue != null &&
      returnValue['type'] != null &&
      returnValue['type'] != 'System.Void') {
    final mapped = mapType(
      returnValue['type'] as String?,
      returnValue['typeSimple'] as String?,
      typesMap,
    );
    returnType = mapped.dartType;

    for (final imp in mapped.imports) {
      _addServiceImport(
        importMap,
        imp.typeName,
        typeLocations,
        controllerGroup,
      );
    }
  }

  // Detect if any body param DTO contains IRemoteStreamContent/IFormFile
  var hasStreamInBody = false;
  for (final bp in bodyParams) {
    final paramList = action['parameters'] as List<dynamic>? ?? [];
    for (final p in paramList) {
      final pm = p as Map<String, dynamic>;
      if (pm['name'] == bp.name) {
        if (dtoContainsStreamContent(pm['type'] as String?, typesMap)) {
          hasStreamInBody = true;
        }
        break;
      }
    }
  }

  return _MethodData(
    name: methodName,
    httpMethod: httpMethod,
    urlTemplate: urlTemplate,
    summary: action['summary'] as String? ?? '',
    returnType: returnType,
    pathParams: pathParams,
    queryParams: queryParams.isNotEmpty ? queryParams : null,
    formDataParams: formParams.isNotEmpty ? formParams : null,
    bodyParams: bodyParams,
    allParams: allParams,
    hasStreamContentInBody: hasStreamInBody,
    apiVersion: apiVersion,
  );
}

/// Determine the binding source for a parameter.
String _resolveBindingSource(Map<String, dynamic> param, String httpMethod) {
  final bindingSourceId = param['bindingSourceId'] as String?;
  if (bindingSourceId != null) {
    switch (bindingSourceId) {
      case 'Path':
        return 'Path';
      case 'Query':
        return 'Query';
      case 'Body':
        return 'Body';
      case 'Form':
      case 'FormFile':
        return 'Form';
      case 'ModelBinding':
        return bodyMethods.contains(httpMethod) ? 'Body' : 'Query';
    }
  }

  return bodyMethods.contains(httpMethod) ? 'Body' : 'Query';
}

/// Check if a controller looks like an ABP integration service.
///
/// ABP integration services typically implement IIntegrationService or have
/// controller names ending with "IntegrationService".
bool _looksLikeIntegrationService(Map<String, dynamic> ctrl) {
  final name = (ctrl['controllerName'] ?? '') as String;
  final interfaces = ctrl['interfaces'] as List<dynamic>?;
  if (name.contains('IntegrationService')) return true;
  if (interfaces != null) {
    for (final iface in interfaces) {
      final ifaceStr = iface.toString();
      if (ifaceStr.contains('IIntegrationService')) return true;
    }
  }
  return false;
}

/// Add an import to the service import map.
void _addServiceImport(
  Map<String, Set<String>> importMap,
  String typeName,
  Map<String, String> typeLocations,
  String currentControllerGroup,
) {
  final location = typeLocations[typeName];
  if (location == null) return;

  final fromDir = currentControllerGroup.replaceAll('\\', '/');
  final toFile = location.replaceFirst(RegExp(r'^\./'), '');

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

// --- Private data classes ---

class _MethodData {
  final String name;
  final String httpMethod;
  final String urlTemplate;
  final String summary;
  final String returnType;
  final List<_ParamInfo> pathParams;
  final List<_ParamInfo>? queryParams;
  final List<_ParamInfo>? formDataParams;
  final List<_ParamInfo> bodyParams;
  final List<_ParamInfo> allParams;

  final bool hasStreamContentInBody;
  final String? apiVersion;

  const _MethodData({
    required this.name,
    required this.httpMethod,
    required this.urlTemplate,
    required this.summary,
    required this.returnType,
    required this.pathParams,
    required this.queryParams,
    required this.formDataParams,
    required this.bodyParams,
    required this.allParams,
    this.hasStreamContentInBody = false,
    this.apiVersion,
  });

  _MethodData copyWithName(String newName) => _MethodData(
        name: newName,
        httpMethod: httpMethod,
        urlTemplate: urlTemplate,
        summary: summary,
        returnType: returnType,
        pathParams: pathParams,
        queryParams: queryParams,
        formDataParams: formDataParams,
        bodyParams: bodyParams,
        allParams: allParams,
        hasStreamContentInBody: hasStreamContentInBody,
        apiVersion: apiVersion,
      );
}

class _ParamInfo {
  final String name;
  final String varName;
  final String apiName;
  final String type;
  final bool isOptional;
  final bool isArray;
  final String binding;

  const _ParamInfo({
    required this.name,
    required this.varName,
    required this.apiName,
    required this.type,
    required this.isOptional,
    required this.isArray,
    required this.binding,
  });
}
