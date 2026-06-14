# AMAN

AMAN is a property platform project with two main parts:

- `mobile_app`: the Flutter mobile application
- `admin_web`: the React + Vite admin dashboard

## Project Structure

```text
AMAN/
  admin_web/   -> admin dashboard
  mobile_app/  -> Flutter mobile app
```

## Requirements

Make sure these tools are installed before running the project:

- Flutter SDK
- Dart SDK
- Node.js
- npm
- A device or emulator for Flutter

Recommended versions:

- Flutter 3.x
- Node.js 18+ 

## Environment Variables

This project uses Supabase, and some parts also use server-side secrets.

Create your local environment values manually in the needed place:

- `admin_web/.env` for the admin dashboard
- Supabase Edge Function secrets for server-side function keys

Important variables used in this project:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`

Client-safe values:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Secret values that must not be shared publicly:

- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`

## Run the Mobile App

1. Open a terminal in `mobile_app`
2. Install packages:

```powershell
flutter pub get
```

3. Check connected devices:

```powershell
flutter devices
```

4. Run the app:

```powershell
flutter run
```

Useful optional commands:

```powershell
flutter analyze
dart format lib test
```

## Run the Admin Web

1. Open a terminal in `admin_web`
2. Install packages:

```powershell
npm install
```

3. Make sure the local env file exists:

- `admin_web/.env`
- or copy from `admin_web/.env.example`

4. Start the development server:

```powershell
npm run dev
```

If PowerShell blocks `npm`, use one of these:

```powershell
npm.cmd run dev
```

or

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
npm run dev
```

5. Open the local URL shown by Vite, usually:

```text
http://localhost:5173
```

## Build the Admin Web

Inside `admin_web` run:

```powershell
npm run build
```

To preview the production build:

```powershell
npm run preview
```

## Supabase Notes

The mobile app and admin dashboard depend on Supabase data and authentication.

The mobile app also calls Supabase Edge Functions for some features such as:

- recommendations
- notifications support
- admin reports

If these functions are not deployed or their secrets are missing, those features may not work even if the app itself runs correctly.

## Common Issues

### `npm` is disabled in PowerShell

Use:

```powershell
npm.cmd run dev
```

### Flutter packages are missing

Run:

```powershell
flutter pub get
```

### Supabase features are not working

Check:

- Supabase project URL and anon key
- Edge Function secrets
- logged-in user session
- database tables and policies

## Main Files

- [mobile_app/pubspec.yaml](C:/Users/USER/OneDrive/Desktop/Flutter/Test2%20-%20Copy/AMAN/mobile_app/pubspec.yaml)
- [admin_web/package.json](C:/Users/USER/OneDrive/Desktop/Flutter/Test2%20-%20Copy/AMAN/admin_web/package.json)
- [admin_web/src/lib/supabase.js](C:/Users/USER/OneDrive/Desktop/Flutter/Test2%20-%20Copy/AMAN/admin_web/src/lib/supabase.js)
- [mobile_app/lib/main.dart](C:/Users/USER/OneDrive/Desktop/Flutter/Test2%20-%20Copy/AMAN/mobile_app/lib/main.dart)

## Quick Start

For mobile:

```powershell
cd mobile_app
flutter pub get
flutter run
```

For admin web:

```powershell
cd admin_web
npm install
npm.cmd run dev
```
