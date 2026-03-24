# AGENTS.md — BazaarChecklist

This file orients AI coding agents and humans working in this repository.

## Source of truth

- Product scope and MVP boundaries: [docs/PRODUCT.md](docs/PRODUCT.md)
- Documentation precedence and maintenance: [docs/DOCS_GUIDE.md](docs/DOCS_GUIDE.md)
- Data shape and collection names: [docs/DATA_MODEL.md](docs/DATA_MODEL.md)
- Implementation conventions: [docs/AI_CODING.md](docs/AI_CODING.md)
- Firebase project setup checklist: [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)

## Read first

1. [docs/PRODUCT.md](docs/PRODUCT.md) — product intent, MVP boundaries, non-goals.
2. [docs/DATA_MODEL.md](docs/DATA_MODEL.md) — Firestore shape and naming (when finalized).
3. [docs/AI_CODING.md](docs/AI_CODING.md) — conventions and how to add features.

## Hard constraints

- **Scope**: Only implement what docs say is in scope; update `docs/PRODUCT.md` first before adding features.
- **Secrets**: Never commit API keys, `google-services.json` / `GoogleService-Info.plist` contents, or Firebase private keys. Use environment or local-only files per [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md).
- **Parity**: Mobile and web share one Flutter codebase; avoid platform-only features unless documented as an exception.
- **No backend beyond Firebase in v1** unless `docs/PRODUCT.md` explicitly adds a server (e.g. Ruby).
- **Navigation intent**: Keep one owner for post-auth destination (currently `SessionController.preferredTabIndex`), and avoid duplicating tab-reset logic across `LoginPage`, `AuthGate`, and `AppShellPage`.

## Open decisions (fill in after product owner answers)

The following are **not** finalized in docs until you confirm. Reply in chat or edit `docs/PRODUCT.md` / `docs/AI_CODING.md`:

- State management library (Riverpod, Bloc, Provider, other, or TBD).

## Where code lives

- Flutter app: [mobile/](mobile/) (package name may be renamed later; see `pubspec.yaml`).
