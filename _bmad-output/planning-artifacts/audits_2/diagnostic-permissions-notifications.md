# Diagnostic — permissions & notifications

**Généré :** 2026-07-21  
**Base code :** `0.12.1+31` (`pubspec.yaml`)  
**Périmètre :** `activity_permission_resolver.dart` · `notification_service.dart` · `onboarding_cubit.dart` · `profile_cubit.dart` · écrans Today / Settings / My Data  
**Statut global :** `open`

---

## Statut

- **Dernière vérification :** 2026-07-24
- **Statut :** `partial` — #1/#2 onboarding intro feedback + retry (story 31-2) ; post-onboarding CTAs (31-1) ; #4/#5 central mappers + platform error distinction (31-4) ; #6/#7 toggle dedup + background init abandonment (31-6)
- **Story / PR :** 31-1 · 31-2 · 31-4 · 31-6

---

## Synthèse

| Priorité | # | Domaine | Statut |
|----------|---|---------|--------|
| 🔴 P0 | 1 | `permanentlyDenied` jamais distingué | `partial` (31-1 post-onboarding + 31-2 onboarding intro feedback) |
| 🔴 P0 | 2 | Pas de re-demande activité post-onboarding | `partial` (31-1 Retry CTA Today/My Data; 31-2 onboarding retry + no silent advance) |
| 🔴 P0 | 3 | `_initializePlatform` avale les erreurs | `open` |
| 🟡 P1 | 4 | Logique `_mapPermissionStatus` dupliquée / incohérente | `done` (31-4) |
| 🟡 P1 | 5 | Catch générique → `denied` (masque bugs plateforme) | `done` (31-4) |
| 🟡 P2 | 6 | Pas de dédup sur `setGoalNotificationsEnabled` | `done` (31-6) |
| 🟡 P2 | 7 | Timeout background n'annule pas l'init sous-jacente | `done` (31-6) |

---

## 🔴 Critique

### 1. `permanentlyDenied` jamais distingué d'un refus simple

**Statut :** `partial` (31-1 + 31-2) — modèle `PermissionRequestStatus.permanentlyDenied`, CTAs différenciés Settings / Today / My Data post-onboarding ; feedback onboarding intro avec Open Settings (permanent) — **31-2 shipped**.

**Constat (2026-07-21) :** Aucun appel à `status.isPermanentlyDenied` dans `lib/`. Après un refus permanent, `Permission.request()` ne réaffiche plus le dialogue système — seul `openAppSettings()` permet de corriger. L'app ne modélise pas ce cas.

| Référence | Détail |
|-----------|--------|
| `lib/presentation/cubits/onboarding_state.dart:5` | Enum `PermissionRequestStatus { idle, requesting, granted, denied }` — pas de `permanentlyDenied` |
| `lib/presentation/cubits/onboarding_cubit.dart:117-121` | `_mapPermissionStatus` : granted **ou** denied |
| `lib/presentation/cubits/profile_cubit.dart:252-265` | `setGoalNotificationsEnabled` : `request()` puis `hasNotificationPermission()` — échec silencieux (`return false`) |
| `lib/presentation/screens/settings_screen.dart:317-328` | SnackBar générique si `!saved` — pas de CTA Settings |

**Résolution 31-1 :** `mapPermissionStatus` + `NotificationToggleResult` ; Settings SnackBar permanent vs retry ; Today/My Data dual CTA (`commonRetry` / `myDataOpenSettings`).

**Impact concret (avant 31-1) :** Toggle notifications ou bouton onboarding qui « ne fait rien » sans explication après refus permanent.

**Nuances existantes :** `openAppSettings()` est câblé pour l'activité refusée sur Today (`today_screen.dart:552`) et My Data (`background_status_card.dart:83-90`) — mais sans distinguer refus simple vs permanent, et **absent** pour les notifications.

---

### 2. Aucun chemin pour re-demander la permission d'activité après l'onboarding

**Constat :** Seul l'onboarding appelle `permission.request()` pour l'activité. Post-onboarding, seul `openAppSettings()` est proposé quand `TodayStatus.noPermission`.

| Référence | Détail |
|-----------|--------|
| `lib/presentation/cubits/onboarding_cubit.dart:89-100` | `requestActivityPermission()` — seul point `.request()` activité |
| `lib/presentation/onboarding/onboarding_flow.dart:52-55` | Branch on `activityPermissionStatus` — `nextStep()` only on `granted` or explicit Continue — **31-2** |
| `lib/presentation/cubits/today/today_refresh_service.dart:75,119,323` | Passe en `noPermission` si checker false |
| `lib/core/permissions/activity_permission_resolver.dart:12-15` | `isActivityRecognitionGranted()` — lecture status uniquement |
| `lib/presentation/screens/today_screen.dart:500-555` | CTA `openAppSettings()` — pas de `.request()` |

**Statut :** `partial` — chemin Settings existe pour état `noPermission` ; onboarding retry + Continue explicite (**31-2**) ; post-onboarding `.request()` via Retry CTA Today/My Data (**31-1**).

**Impact :** Pedometer bloqué si refus simple au onboarding (utilisateur avance quand même) sans bouton « Réessayer » ; après permanent, Settings seul recours — non guidé depuis onboarding ni notifications.

---

### 3. `_initializePlatform` avale les erreurs sans les remonter

**Statut :** `done` — Story 31-3 (`rethrow` + guard `showGoalReached`)

**Constat :** Le `catch` interne logue puis retourne normalement. L'appelant `initialize()` a un `catch` + `rethrow` qui ne s'exécute jamais sur échec natif.

| Référence | Détail |
|-----------|--------|
| `lib/core/services/notification_service.dart:50-63` | `initialize()` — `rethrow` sur échec `_initFuture` |
| `lib/core/services/notification_service.dart:105-122` | `_initializePlatform` — `catch` sans `rethrow` ; `_initFuture = null` |
| `lib/core/services/notification_service.dart:131-142` | `showGoalReached` — se protège a posteriori via `!_initialized` |

**Impact :** Échec réel d'init plugin indétectable pour `main()` et télémétrie. Seul `showGoalReached()` échoue silencieusement.

**Piste :** `rethrow` dans le catch, ou retourner `Result`/bool depuis `_initializePlatform`.

---

## 🟡 À surveiller

### 4. Logique dupliquée et incohérente entre types de permission

**Statut :** `done` — Story 31-4 (`mapActivityPermissionStatus` / `mapNotificationPermissionStatus` ; activity = `isGranted` only)

| Fichier | Lignes | Comportement |
|---------|--------|--------------|
| `notification_service.dart` | 127 | `isGranted \|\| isLimited \|\| isProvisional` — **correct** pour notifications |
| `activity_permission_resolver.dart` | 15 | Même triplet copié — **incorrect** pour `activityRecognition` / `sensors` |
| `onboarding_cubit.dart` | 118 | Idem dans `_mapPermissionStatus` |

**Risque :** Correction à un seul endroit ; divergence si statuts iOS notification vs Android activity mélangés.

**Piste :** Resolver central par `Permission` type (notification vs activity).

---

### 5. Catch générique masquant les erreurs techniques

**Statut :** `done` — Story 31-4 (`PermissionRequestStatus.failed` + distinct log prefix + intro copy)

| Référence | Détail |
|-----------|--------|
| `lib/presentation/cubits/onboarding_cubit.dart:108-113` | `_resolvePermission` : tout `catch` → `PermissionRequestStatus.denied` |

Bug plateforme indiscernable d'un refus volontaire dans logs/métriques.

---

### 6. Pas de déduplication sur `setGoalNotificationsEnabled`

**Statut :** `done` (31-6)

| Référence | Détail |
|-----------|--------|
| `lib/presentation/cubits/profile_cubit.dart:39,56-70` | `refresh()` protégé par `_refreshInFlight` |
| `lib/presentation/cubits/profile_cubit.dart:239+` | `setGoalNotificationsEnabled` — `_toggleInFlight` coalescing |

Risque faible ; incohérence de pattern dans le même cubit.

---

### 7. `initializeForBackground` timeout n'annule pas le travail sous-jacent

**Statut :** `done` (31-6)

| Référence | Détail |
|-----------|--------|
| `lib/core/services/notification_service.dart:69-84` | `.timeout()` → `return false` sur `TimeoutException` |
| `lib/core/services/notification_service.dart:55,105-117` | `_initGeneration` — late completion ignored after timeout |

État temporairement incohérent (`_initialized` peut flipper plus tard). Test couvert : `notification_service_test.dart:65-73`.

---

## 🟢 Points forts constatés

| Domaine | Preuve |
|---------|--------|
| Testabilité injectable | Typedefs `PermissionRequester`, `NotificationPermissionChecker`, `NotificationPlatformInitializer`, `GoalNotificationPresenter` — onboarding, profile, notification service |
| `isClosed` rigoureux | `ProfileCubit` vérifie après chaque `await` avant `emit` |
| UI vs background isolate | `initialize()` vs `initializeForBackground()` + timeout dédié WorkManager |
| Pas de prompt iOS auto | `DarwinInitializationSettings(requestAlertPermission: false, …)` — `notification_service.dart:95-98` |
| Défense en profondeur affichage | `showGoalReached` : permission → init → try/catch — retour bool |
| Erreurs UI homogènes ProfileCubit | Log debug + retour d'échec, jamais d'exception vers l'UI |
| Tests notification | `test/core/services/notification_service_test.dart` — permission, concurrent init, timeout background |

---

## Todo consolidée (session)

| # | Action | Lié |
|---|--------|-----|
| T1 | État `permanentlyDenied` distinct + CTA `openAppSettings()` (activité + notifications) | #1 |
| T2 | Point de re-demande activité hors onboarding (`.request()` ou Settings guidé) | #2 |
| T3 | Remonter / tracer l'échec réel de `_initializePlatform` (`rethrow` ou signal explicite) | #3 |
| T4 | Centraliser `_mapPermissionStatus` par type de permission | #4 — **done** (31-4) |

---

## Plan d'action suggéré

| Phase | Action |
|-------|--------|
| **Quick fix** | `rethrow` dans `_initializePlatform` catch |
| **Quick fix** | Mapper `isPermanentlyDenied` → état UI + CTA Settings (Settings screen + Today slot) |
| **Story** | Service permission unifié (`ActivityPermissionGate`, `NotificationPermissionGate`) |
| **Story** | Onboarding : ne pas avancer si denied ; retry + lien Settings |
| **Story** | `ProfileCubit.setGoalNotificationsEnabled` : `_toggleInFlight` + feedback permanent-denied |
| **Moyen** | Annuler / ignorer résultat init après timeout background |

---

## Dépendances

| Package | Version | Rôle |
|---------|---------|------|
| `permission_handler` | `^12.0.1` | Status / request / settings |
| `flutter_local_notifications` | `^21.0.0` | Affichage goal reached |

---

## Navigation

- Dossier : [`audits_2/`](./)
- Audit précédent : [`diagnostic-couche-donnees.md`](./diagnostic-couche-donnees.md)
- Audits v1 (erreurs UI) : [`diagnostic-gestion-etat-erreur.md`](../audits/diagnostic-gestion-etat-erreur.md) — E28 backlog permission fragmentée
