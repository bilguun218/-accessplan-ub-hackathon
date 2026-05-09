# AccessPlan UB

Smart-city task & route planner for Ulaanbaatar. Type your day's tasks in free-form Mongolian, hit **Generate**, and the app uses Gemini to parse them, resolves each location, and draws a colored multi-stop driving route on the map.

## How it works

```
User text  ──►  Backend /api/ai/parse-tasks  ──►  Gemini 2.5 Flash
                                                      │
                                                      ▼
                                         List<StandardTask> (JSON)
                                                      │
                          MapScreen ◄─────────────────┘
                              │
                              ├─► PlaceGeocodingService (mock UB places)
                              │       resolves locationText → lat/lng + address
                              │
                              ├─► SegmentRouteService (OSRM, free)
                              │       per-segment driving polyline + distance + duration
                              │
                              └─► Renders colored polylines + numbered markers
                                  + tappable route summary
```

## Project layout

```
lib/
├── core/                          # config, network, router, shared widgets
├── features/
│   ├── auth/                      # login, register, JWT
│   ├── map/
│   │   ├── data/
│   │   │   ├── models/            # PlaceDetail, PlacePrediction, RouteSegment
│   │   │   └── services/          # MapApiService, MockMapApiService,
│   │   │                          # PlaceGeocodingService, SegmentRouteService
│   │   └── presentation/screens/  # MapScreen, _route_summary_panel
│   ├── tasks/
│   │   ├── data/
│   │   │   ├── models/            # StandardTask, ParsedTask
│   │   │   └── services/          # TaskParseService (Gemini)
│   │   └── presentation/screens/  # AddTaskScreen (AI input + Generate)
│   ├── home/                      # MainShellScreen (bottom nav)
│   ├── organizations/
│   └── reports/

backend/
└── src/
    ├── controllers/
    │   ├── auth.controller.ts
    │   ├── maps.controller.ts     # /api/maps/autocomplete, /place-details
    │   └── ai.controller.ts       # /api/ai/parse-tasks (Gemini)
    ├── routes/
    └── server.ts
```

## Standard task model

Both manual & AI inputs converge to:

```dart
class StandardTask {
  String id;
  int order;
  String title;
  String category;          // bank, pharmacy, ...
  String locationText;      // "Тэнгис" or "Khan Bank Zaisan"
  String timeText;          // "өнөөдөр", "evening"
  StandardTaskPriority priority;
  bool needsPlaceSearch;
  String placeSearchQuery;  // "search nearby bank" if generic
  double? lat, lng;
  TaskSource source;        // ai | manual
  String notes;
}
```

## Run

### Backend

```bash
cd backend
npm install
cp .env.example .env   # if you have one — otherwise edit .env directly
# fill MONGO_URI, JWT_*, GOOGLE_MAPS_API_KEY, GEMINI_API_KEY
npm run dev            # http://localhost:5000
```

Required env keys:

| Key | Purpose |
|---|---|
| `MONGO_URI` | Mongo for users/auth |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | Auth tokens |
| `GOOGLE_MAPS_API_KEY` | Places API (`/api/maps/*`) |
| `GEMINI_API_KEY` | Task parsing |
| `GEMINI_MODEL` | Default `gemini-2.5-flash` |

### Flutter app

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:5000/api
```

Android `minSdkVersion` is 26 (required by ML Kit dependencies).

## Endpoints

```
POST /api/auth/register        # create account
POST /api/auth/login           # → { accessToken, refreshToken }
POST /api/auth/refresh
GET  /api/auth/me

GET  /api/maps/autocomplete?input=...
GET  /api/maps/place-details?placeId=...

POST /api/ai/parse-tasks
     body: { "text": "Өнөөдөр банк орно, дараа эмийн сан..." }
     → { "tasks": [ { order, title, category, locationText, timeText,
                       priority, needsPlaceSearch }, ... ] }
```

## Flow

1. App opens **AddTaskScreen** (AI input + Generate).
2. User types Mongolian free text → taps **Generate**.
3. Backend → Gemini → strict JSON task array.
4. App pushes **MapScreen** with the parsed `StandardTask` list.
5. MapScreen reads current location, geocodes each task against the local mock UB places dataset (`MockMapApiService`), then calls OSRM segment-by-segment.
6. Each segment renders as its own colored polyline. Numbered markers + tappable rows in the summary card center the camera on the chosen segment.

## Map services

- **MockMapApiService** — ~350 hand-curated UB places (hotels, banks, pharmacies, shopping centers, etc.) with lat/lng + addresses. Used for both autocomplete and AI-task geocoding.
- **MapApiService** — real Google Find Place + Place Details (used by the in-map search bar).
- **PlaceGeocodingService** — wraps MockMapApiService; strips "search nearby " prefix from AI output and returns `GeocodedPlace { latLng, name, address }`.
- **SegmentRouteService** — OSRM driving routes, no API key.

## Notes

- Free-tier OSRM (`router.project-osrm.org`) is fine for hackathon use; for production, self-host or move to Google Directions.
- Gemini parser is locked to `responseMimeType: application/json` and a Mongolian-aware system prompt. Output is normalized server-side, so the Flutter side trusts the field set.
