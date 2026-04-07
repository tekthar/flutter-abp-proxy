## 0.2.0

- Fix: barrel files are no longer generated at root and module levels to prevent
  ambiguous export errors from duplicate class names across modules.
- Fix: service files now include `import 'dart:convert'` so retrofit-generated
  code can use `jsonEncode` for `Map<String, dynamic>` params in multipart methods.

## 0.1.9

- Fix: `abp_error.dart` model classes now use `abstract class` for freezed v3 compat.
- Fix: `NameValue<T>` now has simple `fromJson`/`toJson` without
  `genericArgumentFactories` to avoid json_serializable issues.
- Fix: root-level barrel file is no longer generated to prevent ambiguous export
  errors when duplicate class names exist across modules.
- Fix: stream/file content parameters (`List<int>`) in multipart methods are now
  always required (non-nullable) to match Retrofit expectations.

## 0.1.8

- Fix: property names that are Dart reserved words (e.g., `default`) are now
  escaped with a `$` suffix and annotated with `@JsonKey(name: '...')`.
- Fix: `NameValue<T>` now includes `fromJson`/`toJson` with
  `@JsonSerializable(genericArgumentFactories: true)` so `json_serializable`
  can handle `NameValue<String>` fields in freezed models.

## 0.1.7

- Fix: empty model classes (no properties) now generate `const factory Foo()` instead
  of `const factory Foo({})` which caused json_serializable parse errors.

## 0.1.6

- Fix: skip `void`-typed parameters in service methods. ABP occasionally marks
  parameters as `System.Void` which is not a valid Dart parameter type.
- Fix: map ABP `typeSimple: "enum"` to `int` instead of leaving it as the
  invalid Dart keyword `enum`.

## 0.1.5

- Fix: generated model classes now use `abstract class` instead of `class` for
  compatibility with freezed v3. Freezed v3 generates mixins with abstract members,
  requiring the host class to be declared abstract.

## 0.1.4

- Fix: methods with multiple `@Body()` parameters now keep only one (the complex
  DTO) as `@Body()` and demote scalar params (`String`, `bool`, `int`, etc.) to
  `@Query()`. Retrofit only allows a single `@Body()` per method.

## 0.1.3

- Fix: `NameValue` now correctly defaults to `NameValue<String>` in all code paths,
  including when used as a generic argument (e.g., `List<NameValue>`, `Map<String, List<NameValue>>`).
- Fix: C# array notation (`Type[]`) is now mapped to `List<Type>` instead of
  falling through to `dynamic /* TODO: unknown type */`.
- Fix: multipart `@Body()` → `@Part()` conversion now works correctly in all cases
  (v0.1.2 fix was not being picked up due to stale global activation).

## 0.1.2

- Fix: `NameValue` without generic type arguments now defaults to `NameValue<String>`
  instead of the bare `NameValue` which fails to compile.
- Fix: multipart methods no longer mix `@Body()` with `@Part()` annotations.
  When a method contains file/stream parameters, all body-bound params are
  converted to `@Part(name: '...')` for valid Retrofit multipart signatures.

## 0.1.1

- Fix: double nullable types (`String??`, `bool??`, `int??`) in generated service parameters.
  When ABP marks a parameter as both nullable in its type (e.g., `typeSimple: "date?"`) and
  optional (`isRequired: false`), the generator no longer appends a second `?`.

## 0.1.0

- Initial release.
- Fetch ABP API definition from a running backend or local JSON file.
- Generate Freezed model classes (`@freezed`) from .NET DTOs with full property mapping.
- Generate enums with `@JsonValue` annotations and optional unknown fallback values.
- Generate Retrofit service classes (`@RestApi()`) from ABP controllers.
- Generate barrel export files for clean imports.
- Smart type mapping: 50+ .NET types mapped to Dart equivalents.
- ABP shared base types generated automatically (PagedResultDto, EntityDto, etc.).
- Module filtering: generate for specific modules or include/exclude lists.
- Service type filtering: application services, integration services, or all.
- API versioning support with URL path and header injection.
- Multipart/form-data detection for file upload endpoints.
- Lock file tracking for reproducible generation.
- Dry-run mode to preview generated files without writing.
- Clean mode to remove output directory before generation.
- SSL certificate validation skip for development environments.
