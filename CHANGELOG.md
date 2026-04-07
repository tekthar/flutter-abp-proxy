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
