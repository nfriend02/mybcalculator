#!/usr/bin/env bash
# Github → Netlify CI: install Flutter, inject env, build web.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_DIR="${HOME}/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --enable-web
flutter --version

# Inject Netlify environment variables into app config assets.
# Prefer `assets/config/app_config.env` — Netlify often blocks files named `.env`.
mkdir -p assets/config
cat > assets/config/app_config.env <<EOF
FIREBASE_API_KEY=${FIREBASE_API_KEY:-}
FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN:-}
FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-}
FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET:-}
FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID:-}
FIREBASE_APP_ID=${FIREBASE_APP_ID:-}
FIREBASE_MEASUREMENT_ID=${FIREBASE_MEASUREMENT_ID:-}
OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY:-}
EXCHANGE_RATE_API_KEY=${EXCHANGE_RATE_API_KEY:-}
GEMINI_API_KEY=${GEMINI_API_KEY:-}
APP_TITLE=${APP_TITLE:-AI Smart Calculator}
APP_DESCRIPTION=${APP_DESCRIPTION:-음성·자연어로 계산, 환율, 날씨까지 한 번에.}
APP_AUTHOR=${APP_AUTHOR:-MyBranch Team}
APP_ICON_URL=${APP_ICON_URL:-/icons/Icon-512.png}
GITHUB_BRANCH_URL=${GITHUB_BRANCH_URL:-}
NETLIFY_SITE_URL=${URL:-}
EOF
cp assets/config/app_config.env .env

flutter pub get
flutter build web --release
