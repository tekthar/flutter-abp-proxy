# flutter_abp_proxy

[![License: LGPL-3.0](https://img.shields.io/badge/License-LGPL--3.0-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0-0175C2.svg)](https://dart.dev)
[![pub.dev](https://img.shields.io/pub/v/flutter_abp_proxy.svg)](https://pub.dev/packages/flutter_abp_proxy)

ABP Framework proxy generator for Flutter -- generates **Retrofit service classes** and **Freezed model classes** from a running ABP backend API definition. Part of the [abpjs](https://github.com/abpjs) ecosystem.

## Overview

The ABP Framework provides proxy generators for Angular (`@abp/ng.schematics`), React (`@abpjs/schematics`), Blazor, and C#. Flutter developers have had no equivalent -- every DTO, service class, and enum had to be written by hand.

`flutter_abp_proxy` closes that gap. It connects to the same `/api/abp/api-definition` endpoint that powers the official generators and produces idiomatic Dart code using the Retrofit + Freezed stack.

The ABP backend remains unchanged. Only the client layer is generated.

## Example

A runnable quickstart app is available at
[tekthar/flutter_abp_proxy_example](https://github.com/tekthar/flutter_abp_proxy_example).
It points at the public ABP CMS Kit demo backend and shows a login screen and a
paged blog post list built entirely from generated services and models.

```bash
git clone https://github.com/tekthar/flutter_abp_proxy_example.git
cd flutter_abp_proxy_example
flutter pub get
flutter run
```

## Related Packages

| Package | Description |
|---|---|
| [abp-react](https://github.com/abpjs/abp-react) | React frontend for ABP Framework |
| [create-abp-react](https://github.com/abpjs/create-abp-react) | CLI scaffolding tool for abp-react projects |
| [flutter_abp_proxy_example](https://github.com/tekthar/flutter_abp_proxy_example) | Runnable Flutter quickstart using this generator |
| **flutter_abp_proxy** | Proxy generator for Flutter/Dart consumers of ABP APIs |

## Features

- Fetches ABP API definition from a running backend or local JSON file
- Generates `@freezed` model classes with `fromJson`/`toJson` support
- Generates enums with `@JsonValue` annotations and unknown fallback values
- Generates enum companion options constants for UI dropdowns
- Generates `@RestApi()` abstract service classes for Retrofit
- Generates ABP shared types (`PagedResultDto`, `EntityDto`, `AuditedEntityDto`, etc.)
- Generates ABP structured error response model (`RemoteServiceErrorResponse`)
- Generates barrel export files
- Writes a lock file (`generate-proxy.json`) for incremental regeneration tracking
- Maps .NET types to Dart types (generics, collections, dictionaries, nullables)
- Handles nested C# class names (`+` delimiter normalization)
- Strips assembly-qualified version info from type names
- Detects `IRemoteStreamContent` inside DTOs for automatic multipart encoding
- Prevents circular reference loops during type resolution
- Prevents self-imports in generated files
- Deduplicates actions with duplicate `uniqueName` values
- Supports API versioning (path and header injection)
- Supports service type filtering (application, integration, or all)
- Supports module filtering (single, include list, or exclude list)
- Escapes Dart reserved words in enum members

## Installation

### Global activation

```bash
dart pub global activate flutter_abp_proxy
```

### As a dev dependency

```yaml
dev_dependencies:
  flutter_abp_proxy: ^0.1.0
```

## Usage

### Generate from a running backend

```bash
flutter_abp_proxy --url https://your-abp-backend.com --output lib/data/proxy --clean
```

### Generate from a local JSON file

```bash
flutter_abp_proxy --file api-definition.json --output lib/data/proxy --clean
```

### With authentication

```bash
flutter_abp_proxy --url https://your-abp-backend.com --token YOUR_BEARER_TOKEN --output lib/data/proxy
```

### Filter by module

```bash
# Single module
flutter_abp_proxy --url https://your-abp-backend.com --module administration-service

# Multiple modules (whitelist)
flutter_abp_proxy --url https://your-abp-backend.com \
  --include-modules administration-service \
  --include-modules identity-service

# Exclude specific modules
flutter_abp_proxy --url https://your-abp-backend.com \
  --exclude-modules audit-logging
```

### Filter by service type

```bash
# Only application services (default -- skips internal ABP integration services)
flutter_abp_proxy --url https://your-abp-backend.com --service-type application

# All services including integration services
flutter_abp_proxy --url https://your-abp-backend.com --service-type all
```

### Dry run

```bash
flutter_abp_proxy --url https://your-abp-backend.com --dry-run
```

## CLI Options

| Option | Description | Default |
|---|---|---|
| `--url <url>` | Base URL of the ABP backend | Required (unless `--file`) |
| `--file <path>` | Load API definition from a local JSON file | - |
| `--token <token>` | Bearer token for authentication | - |
| `--output <dir>` | Output directory | `lib/data/proxy` |
| `--module <name>` | Only generate for this module root path | - |
| `--include-modules` | Whitelist of module root paths (repeatable) | - |
| `--exclude-modules` | Blacklist of module root paths (repeatable) | - |
| `--service-type` | Filter: `application`, `integration`, or `all` | `application` |
| `--unknown-enum-value` | Add unknown fallback member to enums | `true` |
| `--clean` | Remove output directory before generating | `false` |
| `--dry-run` | Preview files without writing | `false` |
| `--skip-ssl` | Skip SSL certificate verification | `false` |

## Generated Output Structure

```
lib/data/proxy/
├── generate-proxy.json            # Lock file (tracks generated modules)
├── shared/
│   └── models/
│       ├── abp_types.dart         # PagedResultDto, EntityDto, etc.
│       └── abp_error.dart         # RemoteServiceErrorResponse
├── <module>/
│   └── <controller>/
│       ├── models/
│       │   ├── <dto_name>.dart         # @freezed class
│       │   ├── <dto_name>.freezed.dart # (generated by build_runner)
│       │   └── <dto_name>.g.dart       # (generated by build_runner)
│       ├── <controller>_service.dart   # @RestApi() abstract class
│       └── <controller>_service.g.dart # (generated by build_runner)
└── barrel.dart                    # Re-exports everything
```

## After Generation

### 1. Configure build ordering

Ensure your `build.yaml` has the correct generator ordering to prevent silent failures:

```yaml
global_options:
  freezed:
    runs_before:
      - json_serializable
  json_serializable:
    runs_before:
      - retrofit_generator
```

### 2. Run build_runner

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Verify

```bash
flutter analyze
```

## Required Dependencies

Your Flutter project needs these dependencies for the generated code to compile:

```yaml
dependencies:
  dio: ^5.0.0
  freezed_annotation: ^3.0.0
  json_annotation: ^4.0.0
  retrofit: ^4.0.0

dev_dependencies:
  build_runner: ^2.0.0
  freezed: ^3.0.0
  json_serializable: ^6.0.0
  retrofit_generator: ^10.0.0
```

## Type Mapping

The generator maps .NET types to Dart equivalents:

| .NET Type | Dart Type |
|---|---|
| `System.String`, `System.Guid`, `System.Uri` | `String` |
| `System.Boolean` | `bool` |
| `System.Int16`, `System.Int32`, `System.Int64`, `System.Byte` | `int` |
| `System.Single`, `System.Double`, `System.Decimal` | `double` |
| `System.DateTime`, `System.DateTimeOffset` | `DateTime` |
| `System.TimeSpan` | `String` |
| `List<T>`, `IEnumerable<T>`, `ICollection<T>` | `List<T>` |
| `Dictionary<K,V>`, `IDictionary<K,V>` | `Map<K, V>` |
| `Nullable<T>` | `T?` |
| `ActionResult<T>` | `T` (unwrapped) |
| `IFormFile` | `File` |
| `IRemoteStreamContent` | `List<int>` |
| `byte[]` | `String` (base64) |

## Generated Code Examples

### Freezed Model

```dart
// GENERATED FILE — DO NOT EDIT BY HAND
import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_dto.freezed.dart';
part 'product_dto.g.dart';

@freezed
class ProductDto with _$ProductDto {
  const factory ProductDto({
    required String id,
    String? name,
    String? description,
    double? price,
  }) = _ProductDto;

  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);
}
```

### Enum with Options

```dart
// GENERATED FILE — DO NOT EDIT BY HAND
import 'package:json_annotation/json_annotation.dart';

enum OrderStatus {
  @JsonValue(-1)
  unknown,

  @JsonValue(0)
  pending,
  @JsonValue(1)
  processing,
  @JsonValue(2)
  completed;
}

/// Ready-to-use options list for [OrderStatus] (useful for dropdowns).
const orderStatusOptions = <({OrderStatus value, String label})>[
  (value: OrderStatus.pending, label: 'Pending'),
  (value: OrderStatus.processing, label: 'Processing'),
  (value: OrderStatus.completed, label: 'Completed'),
];
```

### Retrofit Service

```dart
// GENERATED FILE — DO NOT EDIT BY HAND
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'product_service.g.dart';

@RestApi()
abstract class ProductProxyService {
  factory ProductProxyService(Dio dio, {String baseUrl}) = _ProductProxyService;

  /// GET /api/product-service/products
  @GET('/api/product-service/products')
  Future<PagedResultDto<ProductDto>> getList(
    @Query('Filter') String? filter,
    @Query('Sorting') String? sorting,
    @Query('SkipCount') int? skipCount,
    @Query('MaxResultCount') int? maxResultCount,
  );

  /// GET /api/product-service/products/{id}
  @GET('/api/product-service/products/{id}')
  Future<ProductDto> get(
    @Path('id') String id,
  );

  /// POST /api/product-service/products
  @POST('/api/product-service/products')
  Future<ProductDto> create(
    @Body() CreateProductDto body,
  );
}
```

## How It Works

1. Fetches the ABP API definition from `/api/abp/api-definition?includeTypes=true`
2. Analyzes type ownership (which controller uses which DTO)
3. Maps .NET types to Dart types with full generic and nullable support
4. Generates Freezed models, enums, and Retrofit services
5. Writes barrel exports and a lock file
6. You run `build_runner` to produce the `.freezed.dart` and `.g.dart` files

## Project Structure

```
flutter_abp_proxy/
├── bin/
│   └── flutter_abp_proxy.dart     # CLI entry point
├── lib/
│   ├── flutter_abp_proxy.dart     # Library barrel export
│   └── src/
│       ├── config.dart            # Type mappings, constants, reserved words
│       ├── naming_utils.dart      # Case conversion, identifier sanitization
│       ├── type_mapper.dart       # .NET to Dart type resolution
│       ├── fetch_api_definition.dart  # HTTP fetch / file load
│       ├── model_generator.dart   # Freezed DTOs, enums, ABP types
│       ├── service_generator.dart # Retrofit service generation
│       ├── barrel_generator.dart  # Export file generation
│       ├── lock_file.dart         # Generation tracking
│       └── file_utils.dart        # File I/O helpers
├── pubspec.yaml
└── test/
```

## Development

```bash
# Install dependencies
dart pub get

# Run analyzer
dart analyze

# Format code
dart format .

# Run tests
dart test
```

## Translation Strategy

This package follows the same strategy as the [abpjs](https://github.com/abpjs) ecosystem: translate the official ABP tooling into a different frontend technology while keeping the ABP backend completely unchanged.

| ABP Official | This Package |
|---|---|
| `abp generate-proxy -t ng` (Angular) | `flutter_abp_proxy` (Flutter/Dart) |
| `@Injectable` Angular services | `@RestApi()` Retrofit abstract classes |
| TypeScript interfaces | `@freezed` Dart classes |
| TypeScript enums | Dart enums with `@JsonValue` |
| `HttpClient` (Angular) | `Dio` (Dart) |
| `RestService` from `@abp/ng.core` | Generated Retrofit methods |

## Acknowledgments

- [ABP Framework](https://abp.io) by Volosoft for the API definition endpoint and proxy generation patterns
- [abp-react](https://github.com/abpjs/abp-react) for establishing the abpjs ecosystem approach
- [swagger_parser](https://pub.dev/packages/swagger_parser) and [openapi_retrofit_generator](https://pub.dev/packages/openapi_retrofit_generator) for lessons learned in Dart code generation

## Contributing

Contributions are welcome. Please open an issue first to discuss proposed changes.

## License

[LGPL-3.0](LICENSE) -- consistent with the [abpjs](https://github.com/abpjs) ecosystem.

Author: [tekthar.com](https://tekthar.com)
