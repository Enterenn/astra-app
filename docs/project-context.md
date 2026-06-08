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

## Versioning (Phase 0 beta)

**Single source of truth:** `pubspec.yaml` → `version: major.minor.patch+build`

Flutter propagates this to Android `versionName` / `versionCode` automatically — no manual Gradle sync.

| Part | Example | When to bump |
|------|---------|--------------|
| `major` (`x`) | `0` | Reserved for **1.0** public launch narrative |
| `minor` (`y`) | `1` | Post–Phase 0 feature tranche |
| `patch` (`z`) | `0` | Bugfix-only hotfix batch |
| `+build` | `+1` | **Every** sideload APK / checklist run (Android `versionCode`) |

**Baseline:** `0.1.0+1` — `0.x` = pre-1.0 OSS beta.

**In-app display:** Profile tab footer reads from `package_info_plus` (built manifest). Checklist row: displayed version must match `pubspec.yaml` and `aapt dump badging` on release APK.

---

## Story completion checklist (applies to every story)

Before marking a story done:

- [ ] All sub-tasks implemented and each **reviewed + committed** separately
- [ ] Acceptance criteria verified (agent states how in review brief)
- [ ] No secrets in committed files (`.env`, keys, etc.)
- [ ] `docs/DEPENDENCIES.md` updated if packages added

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
