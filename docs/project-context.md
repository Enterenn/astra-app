# ASTRA — Project Context for AI Agents

Rules and conventions that apply across all development work on **astra-app** Phase 0.

**Audience:** Baptiste — solo UI/UX designer, Flutter novice, learning mobile development while shipping the Hub App.

---

## Development Workflow: Review Before Commit

Every implementation increment follows this **mandatory gate**. No exceptions unless Baptiste explicitly waives it for a given step.

### Granularity

- **One git commit per completed sub-task** within a story (not one commit per entire story unless the story is a single sub-task).
- Sub-tasks should be logically separable: e.g. schema migration, then repository, then widget — each gets its own commit after review.
- More commits is intentional: better history for future contributors picking up the project mid-stream.

### Agent flow (after each sub-task)

1. **Implement** the sub-task only — minimal scope, no drive-by refactors.
2. **Stop** — do not commit yet.
3. **Deliver a review brief** for Baptiste (see format below).
4. **Wait** for explicit approval: e.g. `OK commit`, `c'est bon`, `valide`, or equivalent.
5. **Only then** stage relevant files, commit with a clear message, and confirm success.

### Review brief format (optimized for Flutter learning)

Use this structure every time:

```markdown
## Review — [sub-task title]

### What changed
- Bullet list of files touched and one-line purpose each.

### Why this way
- Link to ASTRA architecture/PRD where relevant (e.g. single-writer rule, LocalDayCalculator).
- Name the Flutter/Dart concept introduced (e.g. Cubit, FutureBuilder, sqflite migration).

### How to verify
- Concrete steps: command to run, screen to open, expected behavior.
- Mention if `flutter analyze` / tests were run and result.

### Learn this
- 1–3 short notes: what to notice when reading the diff (patterns, pitfalls, vocabulary).

### Suggested commit message
`type(scope): short imperative summary`
```

Keep prose calm and pedagogical — Baptiste reads the diff to learn, not just to approve.

### Commit message convention

Follow repository style: imperative, focused on **why**, scoped where helpful.

Examples:
- `feat(database): add timeseries_samples schema v1 with bucket unique index`
- `feat(today): add GoalRing widget with progress arc states`
- `fix(normalizer): handle step counter reset after reboot`

### What agents must NOT do

- Commit without Baptiste's explicit OK after the review brief.
- Batch multiple sub-tasks into one commit unless Baptiste asks.
- Skip the explanation because the change "seems small".
- Push to remote unless Baptiste explicitly requests it.

---

## Versioning

**Single source of truth:** `pubspec.yaml` → `version: major.minor.patch+build`

Flutter propagates this to Android `versionName` / `versionCode` automatically — no manual Gradle sync.

| Part | Example | When to bump |
|------|---------|--------------|
| `major` (`x`) | `0` → `1` | **Majeur** — breaking change, architecture pivot, or **1.0** public launch |
| `minor` (`y`) | `1` → `2` | **Moyen** — new user-facing feature, story/epic tranche, meaningful UX change |
| `patch` (`z`) | `0` → `1` | **Mineur** or **hotfix** — bug fixes, robustness, no new feature |
| `+build` | `+1` → `+2` | **Always** increment on every release APK / work phase (Android `versionCode`) |

### Work-phase → version bump

Bump `pubspec.yaml` at the **end of each work phase** (audit batch, story, hotfix sprint):

| Phase type | Bump | Example |
|------------|------|---------|
| **Hotfix** | `patch+1`, `build+1` | `0.2.0+2` → `0.2.1+3` |
| **Mineur** | `patch+1`, `build+1` | same as hotfix (fixes only, no new capability) |
| **Moyen** | `minor+1`, `patch=0`, `build+1` | `0.1.1+2` → `0.2.0+3` |
| **Majeur** | `major+1`, `minor=0`, `patch=0`, `build+1` | `0.2.1+3` → `1.0.0+4` (pre-1.0: reserve `1.0.0` for launch) |

Also update `README.md` version line when bumping. Historical checklist rows in `docs/BETA_CHECKLIST.md` are **not** rewritten.

**Current:** `0.2.0+2` — post-audit remediation (bug fixes, stale banners, dead-code cleanup). `0.x` = pre-1.0 OSS beta.

**In-app display:** Profile tab footer reads from `package_info_plus` (built manifest). Release APK: displayed version must match `pubspec.yaml` and `aapt dump badging`.

---

## Test commands

| Context | Command |
|---------|---------|
| **Daily / story work (default)** | `flutter test --exclude-tags slow` |
| **Full suite (CI / before epic close)** | `flutter test` |
| **Single file** | `flutter test test/path/to/file_test.dart` |

The `slow` tag is declared in `dart_test.yaml` and applied via `@Tags(['slow']) library;` in:
- `test/dev/data_inject_service_test.dart` — 25 920-row inject
- `test/dev/lifecycle_simulator_test.dart` — compaction on 90-day dataset
- `test/dev/chart_benchmark_test.dart` — render + query benchmarks
- `test/app_live_pipeline_lifecycle_test.dart` — ~41 s full-app integration

Agent rule: **always run `flutter test --exclude-tags slow`** in the story verification step unless the story explicitly touches a `slow`-tagged file. When it does, add the targeted file to the command instead of running the full slow suite.

---

## Story completion checklist (applies to every story)

Before marking a story done:

- [ ] All sub-tasks implemented and each **reviewed + committed** separately
- [ ] Acceptance criteria verified (agent states how in review brief)
- [ ] No secrets in committed files (`.env`, keys, etc.)
- [ ] `docs/DEPENDENCIES.md` updated if packages added
- [ ] `flutter test --exclude-tags slow` passes (or explicit note if a slow-tagged file is the story's subject)

---

## References

**Entry point:** [`_bmad-output/README.md`](../_bmad-output/README.md)

**Specifications:**

- Architecture: `_bmad-output/planning-artifacts/architecture.md`
- PRD: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md`
- PRD addendum (SQL, ADP): `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md`
- UX: `_bmad-output/planning-artifacts/ux-design-specification.md`
- Epics & stories: `_bmad-output/planning-artifacts/epics.md`
- Decision log: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/.decision-log.md`

**Implementation tracking:**

- Sprint status: `_bmad-output/implementation-artifacts/sprint-status.yaml`
- Readiness assessment: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-25.md`
- Story files (when created): `_bmad-output/implementation-artifacts/stories/`
