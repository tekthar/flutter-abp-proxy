---
title: "Generate your Flutter API layer from an ABP backend in 30 seconds"
published: false
description: "flutter_abp_proxy reads your ABP Framework API definition and generates Retrofit services and Freezed models end-to-end. No hand-written DTOs, no hand-written service classes."
tags: flutter, dart, dotnet, opensource
cover_image:
canonical_url:
---

If you build mobile apps on top of an **ABP Framework** backend, you have probably written this code more times than you can count:

```dart
class ProductDto {
  final String id;
  final String name;
  final double price;
  // ...

  ProductDto.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      name = json['name'],
      price = (json['price'] as num).toDouble();

  Map<String, dynamic> toJson() => { ... };
}

@RestApi()
abstract class ProductService {
  @GET('/api/app/product')
  Future<PagedResultDto<ProductDto>> getList(
    @Query('skipCount') int skipCount,
    @Query('maxResultCount') int maxResultCount,
  );
  // ... 15 more methods
}
```

Multiply by the number of entities in your system. Now multiply again because the backend team just renamed a field. This isn't engineering, it's transcription.

## The gap in ABP's official tooling

ABP ships first-party proxy generators for Angular, React, Blazor, and C#. They all read the same `/api/abp/api-definition` endpoint and emit type-safe clients. The Flutter ecosystem has been left out — until now.

[**`flutter_abp_proxy`**](https://pub.dev/packages/flutter_abp_proxy) is an open-source CLI that closes that gap. Point it at any ABP backend and it emits:

- **Freezed model classes** with `fromJson` / `toJson` for every DTO
- **Retrofit service classes** for every controller
- **ABP shared base types** (`PagedResultDto`, `EntityDto`, `AuditedEntityDto`, etc.)
- **Enums** with `@JsonValue` annotations and an `unknown` fallback for forward compatibility
- **Barrel exports** so your imports stay short

Your ABP backend does not change. Only the client layer is generated.

## 30-second quickstart

```bash
dart pub global activate flutter_abp_proxy

cd your_flutter_app
flutter_abp_proxy --url https://your-abp-backend.com

dart run build_runner build --delete-conflicting-outputs
```

That's it. You now have a fully typed Dart client under `lib/data/proxy/`.

## Using the generated code

Drop a `Dio` client into the generated service and call it like any other:

```dart
import 'package:dio/dio.dart';
import 'data/proxy/cms-kit/blog-post-public/blog-post-public_service.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://cms-kit-demo.abpdemo.com'));
final blogs = BlogPostPublicProxyService(dio);

final page = await blogs.getListAsyncByBlogSlugAndInput(
  'cms-kit-demo', // blogSlug
  null, null, null, null,
  0, 20, // skipCount, maxResultCount
);

for (final post in page.items) {
  print('${post.title} — ${post.author?.userName}');
}
```

Every field on `post` is strongly typed. IDE autocomplete works. Rename a property on the backend? Re-run the generator and the compiler will point you at every broken call site.

## A real example you can clone

I built a minimal quickstart that uses `flutter_abp_proxy` against the **public ABP CMS Kit demo backend**. It has:

- A login screen calling the generated `LoginProxyService`
- A blog post list screen calling the generated `BlogPostPublicProxyService`
- Zero hand-written DTOs — the only code I wrote lives in `lib/main.dart`

Clone it and run it in two commands:

```bash
git clone https://github.com/tekthar/flutter-abp-proxy_example.git
cd flutter_abp_proxy_example
flutter pub get && flutter run
```

Default credentials on the demo backend are `admin` / `1q2w3E*`. You can also tap *"Browse blog posts as guest"* to skip login — the blog list endpoint is public.

## What gets mapped

`flutter_abp_proxy` understands the quirks of .NET and ABP type names:

| .NET | Dart |
|---|---|
| `System.Guid`, `System.String` | `String` |
| `System.Int32`, `System.Int64` | `int` |
| `System.DateTime` | `DateTime` |
| `List<Foo>` / `IEnumerable<Foo>` | `List<Foo>` |
| `Dictionary<K,V>` | `Map<K, V>` |
| `System.Nullable<T>` | `T?` |
| `Foo[]` (C# array) | `List<Foo>` |
| `Microsoft.AspNetCore.Http.IFormFile` | `File` (multipart) |
| `Microsoft.AspNetCore.Mvc.ActionResult<T>` | `T` (unwrapped) |
| `Volo.Abp.Application.Dtos.PagedResultDto<T>` | `PagedResultDto<T>` |

Generic type arguments propagate recursively, nested classes get their C# `+` delimiters normalized, and assembly-qualified version strings get stripped automatically.

## Filtering what you generate

You do not have to generate the entire ABP admin surface on day one. The CLI accepts:

- `--module <name>` — generate a single module
- `--include-modules <list>` — allow-list
- `--exclude-modules <list>` — deny-list
- `--service-type application|integration|all` — filter by ABP service type
- `--dry-run` — preview the files that would be written without touching disk

## Roadmap

`flutter_abp_proxy` is at **v0.2.0** on pub.dev. The initial release was driven by real use in a production mobile app built on top of an ABP backend, so the type mapper has already been hardened against plenty of edge cases:

- Double-nullable types
- `NameValue` without generic arguments
- Multipart `@Body()` → `@Part()` conversion
- Multiple `@Body()` params demoted to `@Query()`
- `abstract class` output for freezed v3 compatibility
- Empty model classes, Dart reserved keyword property names
- C# array notation (`Type[]`), `enum` keyword in type names

Bug reports and pull requests are welcome at [github.com/tekthar/flutter-abp-proxy](https://github.com/tekthar/flutter-abp-proxy).

## What's next

`flutter_abp_proxy` today generates the networking layer. The bigger mission is to become the **Flutter counterpart to ABP's Angular UI** — a full front-end for any ABP backend, out of the box:

- **A full Flutter boilerplate template** — a cloneable starter that mirrors ABP's official Angular UI: auth flow, multi-tenancy, navigation shell, theming.
- **A generated translator** wired into ABP's language API, with ready-to-use widgets like a fully localized login page.
- **Permission-aware widgets** — a `@Permission('...')` layer tied to ABP's permission system, so buttons, routes, and menus hide themselves automatically.
- **Management screens** — pre-built Flutter pages for users, roles, tenants, settings, and audit logs, matching the ones ABP's Angular UI ships with.

The end state is simple: if ABP teams can bootstrap an Angular frontend in one command, they should be able to do the same thing in Flutter.

## Links

- **Package:** [pub.dev/packages/flutter_abp_proxy](https://pub.dev/packages/flutter_abp_proxy)
- **Source:** [github.com/tekthar/flutter-abp-proxy](https://github.com/tekthar/flutter-abp-proxy)
- **Example app:** [github.com/tekthar/flutter-abp-proxy_example](https://github.com/tekthar/flutter-abp-proxy_example)
- **ABP Framework:** [abp.io](https://abp.io)

If this saves you some time, a sponsor on [GitHub Sponsors](https://github.com/sponsors/tekthar) is hugely appreciated — it keeps the project moving.
