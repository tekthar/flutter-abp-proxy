# I stopped hand-writing my Flutter API layer. You can too.

*How a small CLI turned a 500-file chore into a one-line command.*

[IMAGE 1 — HERO]

---

There's a specific kind of silence that falls over a developer at 11pm when they realize they have to rename a field.

Not a function. Not a variable. A **field** — on a DTO that's been copy-pasted into seventeen places across a Flutter codebase, each copy slightly diverged from the others, each one hand-written against an ABP Framework backend that keeps evolving without me.

I sat there staring at `OrderDto` — one of forty in my app — and I did the math. Forty DTOs. Each with a `fromJson`, a `toJson`, and a hand-rolled Retrofit service. Every time the .NET team shipped a new endpoint, I had to reverse-engineer it from the API docs, invent the Dart shape, wire it up, and hope I'd nailed the nullability.

I was transcribing, not engineering. And I was losing.

## The gap nobody talked about

If you work with the [ABP Framework](https://abp.io), you probably know the feeling. ABP is a serious .NET backend framework — batteries included, audit trails, multi-tenancy, identity, the whole thing. And the frontend story has always been great: ABP ships **official proxy generators** for Angular, for React, for Blazor, and for C# clients. You run a command, point it at `/api/abp/api-definition`, and out comes a fully typed client.

Every framework except one.

Flutter developers have been on their own. There is no first-party Dart generator. Every `fromJson`, every `@RestApi()` abstract class, every `PagedResultDto<T>` has to be written and re-written and re-re-written, forever, by hand.

I searched. I asked around. I found a few half-finished GitHub gists and one abandoned Python script that scraped Swagger. Nothing you'd bet a production app on.

So I built it.

[IMAGE 2 — developer desk at night with repetitive DTOs]

## What "built it" actually means

The elevator pitch is simple: a Dart CLI called [`flutter_abp_proxy`](https://pub.dev/packages/flutter_abp_proxy) that reads the same `/api/abp/api-definition` endpoint the official generators use, and emits a complete, idiomatic Dart client — `@freezed` model classes, `@RestApi()` service classes, enums with `@JsonValue` annotations, the ABP shared base types like `PagedResultDto` and `AuditedEntityDto`, and barrel export files to keep your imports clean.

You run it once. Your networking layer appears.

```bash
dart pub global activate flutter_abp_proxy
flutter_abp_proxy --url https://your-abp-backend.com
dart run build_runner build --delete-conflicting-outputs
```

That's the whole thing. Under `lib/data/proxy/` you now have everything — neatly organized by ABP module, typed end-to-end, ready to drop a `Dio` client into.

The elevator pitch is the easy part. The actual work was different.

## Why this took longer than I expected

I thought I was building a transpiler. I was actually building an **etiquette guide for .NET types**.

.NET has opinions about how it describes itself. Some types come back as `System.Nullable<System.Int32>`. Some come back as `System.Int32?`. Some come back with the full assembly version string baked in: `MyApp.ProductDto, MyApp.Contracts, Version=1.5.92.0, Culture=neutral, PublicKeyToken=null`. ABP itself has its own shorthand — `[ProductDto]` means "list of ProductDto", and `{string:int}` means "Map<String, int>". Nested C# classes come back with a `+` delimiter. Generic arity lands as a backtick: `List\`1`.

And that's the *easy* part.

Then there are the edge cases the type mapper has to survive:

- What do you do when ABP returns `NameValue` without a type argument, but the Dart `NameValue<T>` class requires one? (Default to `NameValue<String>`.)
- What do you do when a method is marked `@MultiPart()` and has three `@Body()` parameters? (Retrofit only allows one body per method. Demote the scalars to `@Query()`, keep the DTO.)
- What do you do when the same method has a `@Body()` DTO **and** a `@Part()` file upload? (Retrofit forbids this. Convert the body to a form part.)
- What do you do when a property is named `default`? (That's a Dart reserved word. Escape it with a `$` and add a `@JsonKey(name: 'default')`.)
- What do you do when a parameter is typed as `System.Void`? (Skip it. Dart can't have `void` parameters.)
- What do you do when Freezed v3 changes how its mixins work? (Generate `abstract class` instead of `class`.)

Every single one of those is a real bug I shipped and fixed. My changelog reads like a confessional.

[IMAGE 3 — code generation machine illustration]

## What it feels like to use

The first time I re-ran the generator on our real backend and watched **813 files** materialize in 12 seconds — 506 models, 98 services, 209 barrels, from 26 ABP modules — and then ran `flutter analyze` and got **zero errors**... I actually laughed out loud.

I've spent hundreds of hours of my career writing those files.

What had been a whole-sprint task — "sync the mobile client with the latest backend" — became a two-command ritual. The mobile team stopped dreading backend releases. When a .NET PR renamed a field, I re-ran the generator, the compiler shouted at the exact three places I needed to fix, and I shipped in fifteen minutes.

That's the part that matters. Not the CLI. Not the code. The **loop getting shorter**.

## A runnable example you can clone

I put together a minimal quickstart so you don't have to take my word for any of this. It points at the **public ABP CMS Kit demo backend** (`https://cms-kit-demo.abpdemo.com`) — a real, maintained ABP instance that anyone can hit without credentials. The app has a login screen and a paged blog post list, both built entirely on generated services and models. The only file I wrote by hand is `lib/main.dart`:

[IMAGE 4 — Flutter phone mockup with login screen]

```bash
git clone https://github.com/tekthar/flutter_abp_proxy_example.git
cd flutter_abp_proxy_example
flutter pub get
flutter run
```

Default credentials: `admin` / `1q2w3E*`. Or tap *"Browse blog posts as guest"* to skip login — the list endpoint is public.

Every DTO the app uses, every service it calls, lives under `lib/data/proxy/` and was generated. Not one line of it was typed by me. When the ABP team adds a new endpoint to the demo, I re-run the generator and it appears.

That loop — the one that used to take hours — is the whole point.

## The parts I'm proud of (and the parts I'm not)

I'm proud that the type mapper handles generic arguments recursively, that it unwraps `ActionResult<T>`, that it detects `IRemoteStreamContent` nested inside DTOs and automatically flips the method to multipart, that it generates `unknown` fallback members on enums so a new backend enum value won't crash your old client.

I'm less proud that I shipped a version with `String??` in it. Twice.

I'm proud that the package has **113 passing tests**, that `dart analyze` is clean, that the published package weighs **180 KB** and has zero transitive dependencies beyond `args` and `path`.

I'm less proud of the hour I spent debugging why `freezed` v3 was rejecting `class` declarations before realizing I needed to prefix them with `abstract`.

I'm proud that it's now being used in production on a real mobile app with hundreds of screens and dozens of ABP modules, and that the analyzer reports zero errors on the generated output.

I'm not yet proud of the documentation. That's the next thing.

## What's next

I want to add:
- **A full Flutter boilerplate template** — a cloneable starter that mirrors ABP's official Angular UI: auth flow, multi-tenancy, navigation shell, theming.
- **A generated translator** wired into ABP's language API, with ready-to-use widgets like a fully localized login page.
- **Permission-aware widgets** — a `@Permission('...')` layer tied to ABP's permission system, so buttons, routes, and menus hide themselves automatically.
- **Management screens** — pre-built Flutter pages for users, roles, tenants, settings, and audit logs, matching the ones ABP's Angular UI ships with.

The end state is simple: if ABP teams can bootstrap an Angular frontend in one command, they should be able to do the same thing in Flutter.

Try it. Break it. Tell me what's missing.

---

**Links**

- 📦 [`flutter_abp_proxy` on pub.dev](https://pub.dev/packages/flutter_abp_proxy)
- 🐙 [Source on GitHub](https://github.com/tekthar/flutter-abp-proxy)
- ▶️ [Runnable example app](https://github.com/tekthar/flutter_abp_proxy_example)
- 🌐 [ABP Framework](https://abp.io)

If this saves you even one evening, a [GitHub Sponsors](https://github.com/sponsors/tekthar) tip is appreciated — it's what keeps me maintaining the project.

---

*I'm [Abdulkarim Itani](https://tekthar.com), a mobile engineer working on ABP-backed apps. I write about the unglamorous middle layer between backends and users — the code nobody wants to own, but somebody has to. Follow me if that sounds like your kind of problem.*
