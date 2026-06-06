# ASTRA: Regulatory Position (Phase 0)

**Disclaimer:** This document describes product intent and architectural choices. It is **not legal advice**. Consult qualified counsel before commercial launch, clinical-adjacent features, or cloud sync in the EU.

---

## Product category

ASTRA Phase 0 is a **General Wellness Product**, a **behavioral visibility tool**.

It helps users see their own movement patterns (step counts, daily goals, trends, local export). It does **not** diagnose, treat, monitor disease, or replace professional medical advice.

This aligns with README positioning: *"The step counter that works in airplane mode"*. Proof of local-first behavior, not a clinical claim.

---

## Allowed claims (Phase 0)

| Category | Examples |
|----------|----------|
| Step counting | Today's step total, 5-minute buckets, background accumulation (Android) |
| Goals | Daily step goal, goal-reached notification (local only) |
| Trends | 7-day / 30-day bar charts, weekly trend direction |
| Data sovereignty | CSV export/import, storage footprint, full purge, airplane-mode proof |
| Transparency | Background collection status, last optimization, no cloud account |

Copy tone follows UX spec §4.6: calm, factual, non-judgmental (*"Your steps stay on this device."*).

---

## Prohibited claims and features (Phase 0)

| ❌ Do not claim or imply | Why |
|--------------------------|-----|
| Diagnosis or disease detection | Medical device territory |
| Treatment or therapy | SaMD / MDR risk |
| Clinical thresholds ("abnormal heart rate") | Requires validated clinical evidence |
| Recovery / readiness scores | Opaque health scoring |
| "Medical grade" or equivalent | Unsubstantiated marketing |

Phase 0 stores **steps only**: no BLE wearable vitals, no PPG, no IMU raw traces.

---

## What ASTRA is not

Consistent with README and UX §4.6:

- Not a medical device or diagnostic tool
- Not a gamified fitness app (streaks, leaderboards, paid coaching)
- Not an Apple Health / Google Fit clone with cloud sync
- Not an Open Wearables server, schema vocabulary alignment only

---

## CNIL / GDPR context (local-only, personal use)

ASTRA Phase 0 architecture:

- **No cloud backend**: data stays in on-device SQLite
- **No user account**: no email, no auth layer
- **No third-party analytics** in the health pipeline
- **User as sole controller**: export and purge are first-class

CNIL's April 2025 guidance notes that mobile apps storing health-related data **locally only for personal use** may fall outside typical processor obligations when the user is the sole controller. This is an **architectural advantage to document**, not a guarantee of exemption for every deployment or business model.

**V2+ cloud sync** would reintroduce GDPR obligations (lawful basis, DPA, data minimization, cross-border transfers). Re-evaluate before shipping sync.

---

## FDA General Wellness policy (US framing)

Under FDA General Wellness policy, products intended for **general wellness** (healthy lifestyle, weight management, physical fitness) and that **do not make disease claims** are typically outside device regulation.

ASTRA Phase 0 (step counter + goal visualization + local trends) fits **lifestyle maintenance** when copy stays within allowed claims above.

**Future sensors** (PPG heart rate, HRV, skin temperature on the planned wearable) require re-evaluation before any clinical-adjacent UX or marketing.

---

## Phase 0 technical boundaries supporting this position

| Boundary | Implementation |
|----------|----------------|
| Data minimization | Aggregated time buckets only; no raw sensor exhaust |
| Local-first | Release builds target no `INTERNET` permission (verified in Story 7.2) |
| No remote push | `flutter_local_notifications`, local channels only; no FCM/Firebase |
| Interpretable export | OW-aligned CSV; user-readable columns |

---

## Related documentation

- [README](../README.md), product principles, airplane mode protocol
- [DEPENDENCIES.md](./DEPENDENCIES.md), network policy and package audit
- [UX copy guidelines](../_bmad-output/planning-artifacts/ux-design-specification.md), §4.6
- [Domain research](../_bmad-output/planning-artifacts/research/domain-astra-local-first-health-hub-research-2026-05-22.md), CNIL/FDA sources
