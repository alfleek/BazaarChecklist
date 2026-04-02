# Roadmap

Aligned with a **short MVP window** and **mobile-first** delivery. Phases are sequential unless noted.

| Phase | Goal | Exit criteria |
|-------|------|----------------|
| **0 — Docs & rules** | Planning artifacts and agent rules | This `docs/` set + `.cursor/rules` + [AGENTS.md](../AGENTS.md) |
| **1 — Firebase shell** | Project + Flutter wired + app runs | Firebase apps registered; app builds on at least one mobile target + web |
| **2 — Catalog** | Firestore catalog + browse UI | Seed `catalog_items`; list/search/filter/sort in app (MVP); cache strategy documented |
| **3 — Guest wins** | Local persistence | Guest can save wins and see history + per-item coverage locally |
| **4 — Auth + cloud** | Account sync | Sign-in; runs in `users/{uid}/runs` (including run result tiers); policy for guest merge implemented |
| **5 — Web + hosting** | Parity + deploy | Stretch: web build; Hosting if time allows |

**Stretch**: Web deploy polish, richer catalog polish around `imageThumbUrl`/`imageFullUrl` handling, enchanted-per-item flags. **Challenges** checklist is implemented client-side; server-side gamification beyond runs is still a stretch.

## Class demo script (template)

Fill in before demo day:

1. *Open app as guest → record a win → show item checklist.*
2. *Sign in → show cloud persistence / second device (if available).*

## Confirmed constraints

- Deployed web is **not required** for the grade.
- Guest-to-cloud merge is included in the auth milestone.
- Documentation precedence is defined in [DOCS_GUIDE.md](DOCS_GUIDE.md).
