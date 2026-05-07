# Code Standards & Architecture

## Why this doc exists

MEMOIR_LOG is a single-user app. A naive read says "no need for Clean Architecture — just call Supabase from the widget." We layer it anyway, because:

1. **The repo is a portfolio piece.** Reviewers should see the patterns they'd expect from a senior engineer.
2. **Testability matters even at one user.** If a Groq response shape changes, the test that catches it must not have to boot a real Supabase.
3. **The Master's coursework leans on these patterns.** Practising SOLID where it costs nothing is cheaper than learning it under pressure.

But: every rule below has an explicit exception list. Three lines of duplication is better than four files of premature abstraction.

## The three layers, per feature

```
lib/features/diary/
├── data/
│   ├── datasources/
│   │   ├── diary_remote_data_source.dart   # talks to Supabase
│   │   └── diary_local_data_source.dart    # Hive cache
│   ├── dtos/
│   │   └── entry_dto.dart                  # mirrors the DB row
│   ├── mappers/
│   │   └── entry_mapper.dart               # DTO ↔ Entity
│   └── repositories/
│       └── diary_repository_impl.dart      # implements domain abstract
├── domain/
│   ├── entities/
│   │   └── entry.dart                      # plain Dart, no framework imports
│   ├── failures/
│   │   └── diary_failure.dart              # sealed class
│   ├── repositories/
│   │   └── diary_repository.dart           # ABSTRACT — the contract
│   └── usecases/
│       ├── get_today_entry.dart
│       └── watch_entries.dart
└── presentation/
    ├── providers/
    │   └── diary_providers.dart            # Riverpod wiring
    ├── widgets/
    │   ├── diary_page.dart
    │   ├── pixel_meter.dart
    │   └── typewriter_text.dart
    └── screens/
        └── timeline_screen.dart
```

**Rule of thumb:** the **domain layer must not import anything from `data/` or `flutter/`**. That single rule, mechanically enforced (via lints in `analysis_options.yaml`), buys 80% of the value of Clean Architecture.

## SOLID applied here

| Letter | What it means in this codebase                                                  |
|--------|---------------------------------------------------------------------------------|
| **S** — Single Responsibility | One use case = one verb. `GetTodayEntry`, `WatchEntries`, `MarkEntryRead`. No `DiaryService` god class. |
| **O** — Open/Closed | `Failure` is a sealed class hierarchy. Adding a new failure subtype doesn't modify existing handlers — they fall to the `_` exhaustive case. |
| **L** — Liskov | Concrete repositories must honor the abstract contract end-to-end. Tests instantiate `FakeDiaryRepository` typed as `DiaryRepository`. |
| **I** — Interface Segregation | Repository interfaces are **narrow**. `DiaryRepository` does not expose music ops — that's `MusicRepository`. No 30-method god repos. |
| **D** — Dependency Inversion | Domain depends on abstractions, not implementations. Riverpod wires the concrete at the composition root only. |

The lints to enforce this live in `analysis_options.yaml`:

```yaml
custom_lint:
  rules:
    - avoid_dynamic_calls
    - avoid_final_parameters
analyzer:
  errors:
    # Ban data → domain imports the cheap way: directory-level barrel files
    # plus a CI grep that fails the build on the wrong import.
```

A pre-commit hook greps each `domain/` file for `package:flutter` and `data/` imports. One regex, one failure mode, one truth.

## Dependency Injection — Riverpod, not GetIt

Riverpod is already in for state. Its `Provider` is a fully capable DI container — adding GetIt is two containers in one app for no reason.

```dart
// lib/features/diary/presentation/providers/diary_providers.dart

final diaryRemoteDataSourceProvider = Provider<DiaryRemoteDataSource>((ref) {
  return DiaryRemoteDataSourceImpl(ref.read(supabaseClientProvider));
});

final diaryLocalDataSourceProvider = Provider<DiaryLocalDataSource>((ref) {
  return DiaryLocalDataSourceImpl(ref.read(hiveBoxProvider));
});

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepositoryImpl(
    remote: ref.read(diaryRemoteDataSourceProvider),
    local:  ref.read(diaryLocalDataSourceProvider),
  );
});

final getTodayEntryProvider = Provider<GetTodayEntry>((ref) {
  return GetTodayEntry(ref.read(diaryRepositoryProvider));
});
```

Tests override providers via `ProviderContainer(overrides: [...])`. No `GetIt.reset()` between tests, no global state surprises.

## Error handling — `Either<Failure, T>` at every boundary

Every repository method returns `Future<Either<Failure, T>>` (or `Stream<Either<...>>` for Realtime). Implementation: [`fpdart`](https://pub.dev/packages/fpdart) — actively maintained, cleaner API than the older `dartz`.

```dart
// domain/failures/diary_failure.dart
sealed class DiaryFailure {
  const DiaryFailure(this.message);
  final String message;
}

final class NetworkFailure   extends DiaryFailure { const NetworkFailure(super.message); }
final class ServerFailure    extends DiaryFailure { const ServerFailure(super.message); }
final class CacheFailure     extends DiaryFailure { const CacheFailure(super.message); }
final class NarratorFailure  extends DiaryFailure { const NarratorFailure(super.message); }
final class UnknownFailure   extends DiaryFailure { const UnknownFailure(super.message); }

// data/repositories/diary_repository_impl.dart
@override
Future<Either<DiaryFailure, Entry>> getTodayEntry(String userId) async {
  try {
    final dto = await _remote.fetchTodayEntry(userId);
    await _local.cache(dto);
    return Right(dto.toEntity());
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message));
  } on SocketException {
    final cached = await _local.read(userId);
    return cached != null
      ? Right(cached.toEntity())
      : const Left(NetworkFailure('offline and no cached entry'));
  } catch (e) {
    return Left(UnknownFailure(e.toString()));
  }
}
```

**Rule:** exceptions are caught at the data-layer boundary and converted to `Either`. They never cross into domain or presentation. Presentation pattern-matches on `Failure` to render terminal-voice error states (`> CONNECTION TIMEOUT...`).

## Theming — `ThemeExtension` for retro tokens

The CRT palette and typography live in a `ThemeExtension`, **not** in widgets. This is the line between "we have a design system" and "we hard-coded `Colors.amber` in 47 places."

```dart
// app/theme/crt_theme.dart
class CrtTheme extends ThemeExtension<CrtTheme> {
  const CrtTheme({
    required this.fgBright,
    required this.fgDim,
    required this.fgGhost,
    required this.glow,
    required this.bodyType,
    required this.uiType,
    required this.dateHeaderType,
    required this.scanlineOpacity,
  });

  final Color fgBright;
  final Color fgDim;
  final Color fgGhost;
  final Color glow;
  final TextStyle bodyType;       // VT323 22
  final TextStyle uiType;         // Share Tech Mono 14
  final TextStyle dateHeaderType; // Press Start 2P 11
  final double scanlineOpacity;

  factory CrtTheme.amber()    => CrtTheme(/* ... */);
  factory CrtTheme.phosphor() => CrtTheme(/* ... */);

  @override
  CrtTheme copyWith({ /* ... */ }) => /* ... */;

  @override
  CrtTheme lerp(CrtTheme? other, double t) => /* ... */;
}

extension CrtThemeContext on BuildContext {
  CrtTheme get crt => Theme.of(this).extension<CrtTheme>()!;
}

// Usage in a widget:
Text(
  date,
  style: context.crt.dateHeaderType.copyWith(color: context.crt.fgBright),
);
```

Switching palette is one provider write — every screen re-renders against the new extension. No `if (palette == amber) ...` in widgets.

## When NOT to use full layering

Layering is a **tool**, not a tax. Skip pieces when the abstraction earns nothing:

| Situation                                          | What to skip                                    |
|----------------------------------------------------|-------------------------------------------------|
| Single-call CRUD with no business logic            | Use case class. Repository → provider directly. |
| Pure UI (typewriter, scanlines, page transitions)  | Domain layer entirely. Live in `presentation/`. |
| Settings toggle that flips a row                   | DTO + mapper. Use the entity throughout.        |
| Edge Function-only logic (cron jobs, polling)      | Don't model in Flutter at all. The function is the entity. |
| One-off data migration scripts                     | Skip the structure. A `tools/` folder is fine.  |

If a feature has only one method and no logic, **promote the repository to a Riverpod `FutureProvider.family`** and stop. Re-introduce the layers when a second method or a piece of business logic shows up.

## Naming conventions

| Element             | Pattern                | Example                       |
|---------------------|------------------------|-------------------------------|
| Entity              | Domain noun            | `Entry`, `Workout`, `VoiceNote` |
| DTO                 | Suffixed `Dto`         | `EntryDto`                    |
| Mapper              | Suffixed `Mapper` or extension on DTO | `EntryMapper.toEntity()` or `EntryDtoX.toEntity()` |
| Use case            | Verb-Noun, class       | `GetTodayEntry`, `WatchEntries`, `MarkEntryRead` |
| Failure             | Suffixed `Failure`     | `NetworkFailure`, `NarratorFailure` |
| Repository abstract | Suffixed `Repository`  | `DiaryRepository`             |
| Repository concrete | Suffixed `RepositoryImpl` | `DiaryRepositoryImpl`      |
| Riverpod provider   | Suffixed `Provider`    | `getTodayEntryProvider`       |

`final` over `const` only when the latter is impossible. `late final` is a smell — usually means a missing constructor parameter.

## Testing strategy

| Layer                  | Test type        | What it covers                                  |
|------------------------|------------------|-------------------------------------------------|
| Use cases              | Unit             | Business logic with mocked repository.          |
| Repositories           | Unit             | DTO ↔ entity mapping + failure conversions.     |
| Mappers                | Unit             | All edge cases (nullable fields, locale dates). |
| Widgets (key components)| Widget          | DiaryPage, PixelMeter, TypewriterText.          |
| DiaryPage in both palettes | Golden       | Catches palette regressions in CI.              |
| Whole app              | Manual TestFlight | Integration — not worth automating at v1.      |

Mocking: `mocktail` (no codegen). Test files mirror source: `lib/features/diary/domain/usecases/get_today_entry.dart` → `test/features/diary/domain/usecases/get_today_entry_test.dart`.

## Edge Function (Deno) standards

The TypeScript side of the project follows a lighter version of the same principles:

- **One function = one entry point** (`index.ts`). Keep deps small — native `fetch`, no axios.
- **Inputs validated with `zod`** at the boundary; throw a `400` if the cron payload is wrong shape.
- **Failures returned as `{ ok: false, error }`** — never throw past the response boundary. The cron caller logs `integration_runs.status='error'` based on the JSON.
- **No `any`.** If a type comes from an external API, type the response shape narrowly.
- **Timeouts everywhere.** `fetch` calls wrapped in `AbortSignal.timeout(15000)`. Groq is fast; if it isn't responding in 15s, retry tomorrow.

```ts
// supabase/functions/daily-summary/index.ts
import { z } from 'https://esm.sh/zod';

const Input = z.object({ user_id: z.string().uuid(), date: z.string() });

Deno.serve(async (req) => {
  const parsed = Input.safeParse(await req.json());
  if (!parsed.success) return Response.json({ ok: false, error: 'bad_input' }, { status: 400 });

  // ... aggregate, call Groq, write entries row
  return Response.json({ ok: true });
});
```

## Pre-commit & CI

- `dart format --set-exit-if-changed lib/ test/`
- `dart analyze --fatal-infos`
- `flutter test`
- Custom grep: domain layer must not import `package:flutter` or `data/`.
- Edge Functions: `deno fmt --check`, `deno lint`, `deno test`.

CI fails closed. No "I'll fix it later" merges.
