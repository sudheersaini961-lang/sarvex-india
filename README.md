# SARVEX INDIA

SARVEX INDIA is an Indian multi-vendor marketplace web and mobile application built with React, TypeScript, Vite, Tailwind CSS, and Capacitor. It provides buyer storefront browsing, cart and checkout flows, order tracking, seller product management, and admin dashboard modules.

> **Honest launch status (16 Nov 2026):** This is a working development build, not a live marketplace. The app uses local state until a real Supabase project is configured. COD checkout is deliberately disabled until courier PIN serviceability, cash collection and seller remittance are integrated and verified. Dropship stock reservation is implemented and tested, but dropship order creation, payment capture and customer checkout are not enabled. See [Launch readiness](docs/LAUNCH_READINESS.md) for the exact completed work and remaining external requirements.

## Prerequisites

- **Node.js** (v22 recommended) and **npm**
- **JDK 21** and **Android SDK** (only required if building the Android APK locally instead of using GitHub Actions)

## Supabase administrator setup

For the one-time, privileged first-admin procedure, see [docs/ADMIN_BOOTSTRAP.md](docs/ADMIN_BOOTSTRAP.md). Do not expose a service-role key in the client app.

## Installation & Local Development

1. Install dependencies:
   ```bash
   npm install
   ```
2. *(Optional)* Configure local environment variables by copying `.env.example` to `.env.local` and adding your own public values (`VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`). Never place a Supabase `service_role` key or private secret in client `.env*` files.
3. Start the development server (runs on port `3000`):
   ```bash
   npm run dev
   ```

## Available Scripts

- `npm run dev` — Start the Vite development server on port `3000`
- `npm run lint` — Run TypeScript type checking (`tsc --noEmit`)
- `npm run build` — Build the web bundle into `dist/`
- `npm run preview` — Preview the built `dist/` bundle locally

## Android APK Build (Capacitor)

The Capacitor Android wrapper is configured in `capacitor.config.ts` (`appId: com.sarvex.india`, `appName: SARVEX India`, `webDir: dist`).

### Option 1: GitHub Actions (No Local Android SDK Needed)

1. Push the repository to GitHub (`main` branch).
2. *(Optional)* Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` under **Settings → Secrets and variables → Actions → Variables**.
3. Open **Actions → Build SARVEX Android Debug APK → Run workflow**.
4. Download the generated `sarvex-india-debug-apk` (`app-debug.apk`) artifact from the completed workflow run.

### Option 2: Local Android Debug APK Build

1. Build the web bundle and sync assets into the Android project:
   ```bash
   npm run lint
   npm run build
   npx cap sync android
   ```
2. Build the debug APK using Gradle (requires JDK 21 and Android SDK):
   ```bash
   cd android
   ./gradlew assembleDebug
   ```
3. The debug APK output is written to `android/app/build/outputs/apk/debug/app-debug.apk`.
