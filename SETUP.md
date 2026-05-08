# AccessPlan UB — Authentication Foundation

Mobile app (Flutter) + REST backend (Node.js / Express / TypeScript / MongoDB).
Only authentication is implemented in this module: register, login, JWT,
refresh, forgot/reset password, protected `/auth/me` and a Home/Profile screen.

## Repository layout

```
.
├── backend/              # Node.js + Express + TypeScript API
└── lib/                  # Flutter app (mobile-first)
    ├── core/             # config, network, storage, router, widgets
    └── features/
        ├── auth/         # data + domain + presentation
        └── home/
```

## Backend

Requires Node 18+ and a running MongoDB on `mongodb://localhost:27017`.

```bash
cd backend
cp .env.example .env       # fill in JWT secrets
npm install
npm run dev                # starts on http://localhost:5000
```

Endpoints (all under `/api/auth`):

| Method | Path              | Auth     |
| ------ | ----------------- | -------- |
| POST   | /register         | public   |
| POST   | /login            | public   |
| POST   | /refresh          | public   |
| POST   | /logout           | public   |
| POST   | /forgot-password  | public   |
| POST   | /reset-password   | public   |
| GET    | /me               | Bearer   |

In development the password reset email is **printed to the server console**
(token + deep link + web link) instead of sent via SMTP.

## Flutter app

Requires Flutter SDK 3.9+. Existing project at repo root.

```bash
flutter pub get

# Android emulator (API on host machine):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api

# Physical device on same Wi-Fi:
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:5000/api
```

App flow:

1. `SplashScreen` runs `AuthProvider.checkAuth()`.
2. If access token is valid → `HomeScreen`.
3. If access token is expired → tries `/auth/refresh` once.
4. Anything else → `LoginScreen`.

Tokens are stored in `flutter_secure_storage`. Dio's interceptor auto-attaches
the Bearer token and retries once on a 401 by hitting `/auth/refresh`.

## Future modules (not built yet)

Daily planner, route planning, organization database, citizen complaints,
map/traffic. The folder structure under `lib/features/` is ready for each.
