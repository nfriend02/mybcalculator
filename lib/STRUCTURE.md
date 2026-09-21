# AI Smart Calculator — Feature-Sliced Design (FSD)
#
# lib/
# ├── main.dart                 # Entry: Firebase + dotenv + runApp
# ├── firebase_options.dart     # Options from .env
# ├── app/                      # App layer (DI, router, theme)
# ├── pages/                    # Composition / route screens
# ├── features/                 # Feature slices (ui / model / domain)
# ├── entities/                 # Business entities
# └── shared/                   # Shared config, API, UI, services
#
# Layers may only import from same or lower layers:
#   pages → features → entities → shared
#   app may compose all layers for wiring.
#
# Note: feature internals use `domain/` (not `lib/`) to avoid Dart package-lib conflicts.
