# BazaarChecklist mobile

Flutter client for BazaarChecklist (mobile-first, web-capable).

## Common commands

From `mobile/`:

```bash
flutter pub get
flutter run
flutter test
```

## Architecture

- Feature code lives in `lib/features/`.
- Shared app bootstrap/navigation lives in `lib/main.dart` and top-level app files.
- Product and data-shape source of truth:
  - `../docs/PRODUCT.md`
  - `../docs/DATA_MODEL.md`

## Firebase

See `../docs/FIREBASE_SETUP.md` for project setup and seeding options.
