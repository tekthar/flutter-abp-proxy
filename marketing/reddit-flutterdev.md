# r/FlutterDev post

**Important:** r/FlutterDev is strict on self-promotion. Read their rules before posting. The safest approach is to post as *"I made a thing, here it is, here's an example, here's the problem it solves"* — not as marketing. Engage with replies, don't just drop the link.

Best days/times to post: weekday mornings US Eastern.

---

## Title options (pick one)

1. **I built a Retrofit/Freezed code generator for Flutter apps that consume ABP Framework backends**
2. **flutter_abp_proxy: generate your entire API layer from an ABP backend .NET API definition**
3. **Tired of hand-writing DTOs? I wrote a generator that turns any ABP Framework backend into a typed Dart client**

Recommended: **#1** — it's descriptive and doesn't read like clickbait.

---

## Post body

Hey r/FlutterDev —

I maintain a Flutter app that talks to an **ABP Framework** (.NET) backend. ABP ships official proxy generators for Angular, React, Blazor, and C#, but there has never been one for Flutter. Every DTO and every service class had to be written by hand, and every backend rename turned into a scavenger hunt.

So I built **[flutter_abp_proxy](https://pub.dev/packages/flutter_abp_proxy)**. It reads the same `/api/abp/api-definition` endpoint that powers the official generators and emits:

- `@freezed` model classes with `fromJson`/`toJson`
- `@RestApi()` Retrofit service classes
- ABP shared base types (`PagedResultDto`, `EntityDto`, `AuditedEntityDto`, ...)
- Enums with an `unknown` fallback for forward compatibility
- Barrel export files

Your backend doesn't change — only the client layer is generated.

### Quickstart

```bash
dart pub global activate flutter_abp_proxy
flutter_abp_proxy --url https://your-abp-backend.com
dart run build_runner build --delete-conflicting-outputs
```

Generated code lands under `lib/data/proxy/` and you use it like any Dio-based service:

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://your-abp-backend.com'));
final blogs = BlogPostPublicProxyService(dio);
final page = await blogs.getListAsyncByBlogSlugAndInput(
  'my-blog', null, null, null, null, 0, 20,
);
```

### Runnable example

I put together a minimal quickstart app that points at the **public ABP CMS Kit demo backend** (`https://cms-kit-demo.abpdemo.com`). It has a login screen and a paged blog post list, both built on generated services. The only hand-written code lives in `lib/main.dart`:

→ **[github.com/tekthar/flutter_abp_proxy_example](https://github.com/tekthar/flutter_abp_proxy_example)**

Clone, `flutter pub get`, `flutter run`. No backend setup needed.

### Current status

v0.2.0 on pub.dev. The type mapper has already been hardened against a pile of real-world edge cases (double-nullable types, multipart `@Body`/`@Part` mixing, C# array notation, freezed v3 compatibility, Dart reserved keywords, etc). It's being used in production in a mobile app with 500+ generated files and zero analyzer errors.

### Where this is heading

The networking layer is step one. The bigger goal is a **Flutter counterpart to ABP's Angular UI** — a full front-end for any ABP backend:

- A full Flutter boilerplate template (auth, multi-tenancy, navigation shell, theming — same shape as ABP's Angular starter)
- A generated translator wired into ABP's language API, with localized widgets like a ready-made login page
- Permission-aware widgets — a `@Permission('...')` layer that hides buttons/routes automatically
- Management screens — pre-built Flutter pages for users, roles, tenants, settings, and audit logs

If ABP teams can bootstrap an Angular frontend in one command, they should be able to do the same in Flutter.

If you use ABP with Flutter, I'd love feedback. If you hit a backend shape the generator doesn't handle, open an issue with the offending type and I'll take a look:

→ **[github.com/tekthar/flutter-abp-proxy](https://github.com/tekthar/flutter-abp-proxy)**

---

## Engagement checklist

- [ ] Reply to every comment within the first 2 hours (Reddit rewards early engagement)
- [ ] If someone asks "how does this compare to X", answer technically, not defensively
- [ ] If a mod removes the post for promo, ask what would make it compliant and edit
- [ ] Cross-post to r/dartlang after a day or two if r/FlutterDev goes well
