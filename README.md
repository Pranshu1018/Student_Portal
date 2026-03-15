# Student Portal

A full-stack mobile learning app built with Flutter + Firebase + FastAPI. Students can study notes, take AI-generated quizzes, practice coding, and track their progress across 6 CS subjects.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Dart) + Riverpod |
| Auth & Database | Firebase Auth + Firestore |
| Backend API | FastAPI (Python) |
| AI Quiz Generation | Google Gemini API |
| Web Scraping | BeautifulSoup4 + GFG/TutorialsPoint |
| Code Execution | Judge0 API (via RapidAPI) |

---

## Features

- **Auth** — Register/login with Firebase Auth, role-based routing (student vs admin)
- **Subjects & Topics** — 6 subjects, 60+ topics seeded in Firestore (DSA, DBMS, OS, CN, Python, Java)
- **Notes** — Auto-fetched from GeeksForGeeks/TutorialsPoint via web scraping, cached in Firestore
- **AI Quizzes** — 10 fresh MCQs generated per topic on-demand using Gemini, with difficulty mix and explanations
- **Code Practice** — In-app code editor with Judge0 execution
- **Progress Tracking** — XP, streaks, per-subject progress bars, all stored in Firestore
- **Analytics** — Quiz history, accuracy, recent activity
- **Admin Panel** — Manage topics, seed data, scrape content, add quiz questions

---

## Project Structure

```
student_portal/
├── lib/                          # Flutter app
│   ├── main.dart
│   ├── core/constants/           # Colors, API constants
│   ├── models/                   # Dart models
│   ├── providers/                # Riverpod providers
│   ├── services/                 # Firebase + API services
│   └── screens/
│       ├── auth/                 # Login, Register
│       ├── home/                 # Home dashboard
│       ├── subjects/             # Subjects, Topics, Topic Detail
│       ├── quiz/                 # Quiz screen + Results
│       ├── code/                 # Code practice
│       ├── analytics/            # Analytics screen
│       └── admin/                # Admin panel
├── backend/                      # FastAPI backend
│   ├── main.py                   # All routes
│   ├── core/firebase.py          # Firestore client
│   ├── services/
│   │   ├── scraper_service.py    # GFG/TP web scraper
│   │   └── quiz_generator.py     # Gemini quiz generator
│   ├── serviceAccountKey.json    # Firebase credentials (not committed)
│   ├── .env                      # Environment variables (not committed)
│   └── requirements.txt
└── assets/
    └── code_editor.html          # WebView code editor
```

---

## Setup

### Prerequisites

- Flutter 3.x
- Python 3.11+
- Firebase project with Firestore + Auth enabled
- Gemini API key (free) — [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)

---

### 1. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Email/Password) and **Firestore**
3. Add an Android app, download `google-services.json` → place in `android/app/`
4. Run `flutterfire configure` to generate `lib/firebase_options.dart`
5. Go to **Project Settings → Service Accounts → Generate new private key** → save as `backend/serviceAccountKey.json`

---

### 2. Backend Setup

```bash
cd backend
pip install -r requirements.txt
```

Create `backend/.env`:

```env
FIREBASE_SERVICE_ACCOUNT_PATH=serviceAccountKey.json
GEMINI_API_KEY=your_gemini_api_key_here
```

Start the backend:

```bash
uvicorn main:app --reload
```

API runs at `http://127.0.0.1:8000`. On Android emulator, the app connects via `http://10.0.2.2:8000`.

---

### 3. Flutter Setup

```bash
flutter pub get
flutter run
```

---

### 4. Seed Data (first run)

Log in as admin and use the **Admin Panel** to:
1. **Seed Subjects** — creates 6 subjects in Firestore
2. **Seed Topics** — creates 60+ topics across all subjects

---

## Backend API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/topics/{id}/quiz` | Generate 10 AI questions for a topic |
| POST | `/api/notes/fetch` | Scrape notes for a topic title |
| POST | `/api/admin/scrapeTopicContent` | Scrape a specific URL |
| POST | `/api/code/execute` | Execute code via Judge0 |

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Yes | Path to service account JSON file |
| `GEMINI_API_KEY` | Yes | Google Gemini API key |
| `RAPIDAPI_KEY` | No | RapidAPI key for Judge0 code execution |

---

## How the Quiz Works

1. User opens a topic and taps **Take Quiz**
2. Flutter calls `GET /api/topics/{topic_id}/quiz`
3. Backend reads the topic's scraped content from Firestore
4. Sends content to Gemini → gets 10 fresh MCQs (easy/medium/hard mix)
5. Questions returned directly to Flutter — nothing stored in Firestore
6. User answers → score calculated locally → saved to Firestore via `saveQuizResult()`
7. XP and streak updated atomically in the user document

> The topic must have content loaded first. Open the **Notes** tab once to fetch and cache content before taking a quiz.

---

## Notes on Gemini Quota

The free tier has a daily limit per model per Google Cloud project. If you hit quota:

- The backend automatically tries fallback models: `gemini-2.0-flash` → `gemini-2.0-flash-lite` → `gemini-2.5-flash`
- If all fail, create a new API key under a **different Google Cloud project** — each project has its own quota
- Quota resets daily at midnight Pacific time

---

## Production Behaviour

| Feature | On Render | Notes |
|---|---|---|
| Quiz generation (Gemini) | ✅ Works | Gemini API calls go out fine from any server |
| Firebase Auth / Firestore | ✅ Works | No issues |
| Notes (web scraping) | ⚠️ May be blocked | GFG uses Cloudflare which blocks datacenter IPs |
| Code execution (Judge0) | ✅ Works | External API call |

**Web scraping workaround:** Content is cached in Firestore after the first successful fetch. The recommended workflow is:

1. Run the backend locally (`uvicorn main:app --reload`)
2. Open each topic's Notes tab in the app — this scrapes and caches content in Firestore
3. Deploy to Render — the app reads from Firestore cache, scraping never needs to run on the server

Wikipedia is used as a fallback when GFG/TP are blocked, so notes will always have *something* even in production.

### Backend → Render

1. Push this repo to GitHub
2. Go to [render.com](https://render.com) → New → Web Service → connect your repo
3. Render auto-detects `render.yaml` — no manual config needed
4. In the Render dashboard, go to **Environment** and add these two secret vars:

**`GEMINI_API_KEY`**
```
AIza...your_key
```

**`FIREBASE_SERVICE_ACCOUNT_JSON`**
Paste the entire contents of `serviceAccountKey.json` as a single-line string:
```json
{"type":"service_account","project_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"..."}
```
To get it as one line, run:
```bash
python -c "import json; f=open('backend/serviceAccountKey.json'); print(json.dumps(json.load(f)))"
```

5. Deploy. Your backend URL will be `https://your-app-name.onrender.com`

6. Update `lib/core/constants/api_constants.dart`:
```dart
static const bool _isProduction = true;
static const String _productionUrl = 'https://your-app-name.onrender.com/api';
```

---

### Flutter App → APK / Play Store

Flutter is a **mobile app**, not a web app, so it doesn't deploy to Vercel. Options:

**Build APK (simplest):**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```
Share the APK directly or upload to Play Store.

**Flutter Web (if you want a web version):**
```bash
flutter build web
# Then deploy the build/web/ folder to Vercel or Netlify
```
Note: Flutter Web has limitations — Firebase Auth and some plugins may behave differently.

---

### What to push to GitHub

Safe to commit:
- All `lib/` Flutter code
- `backend/` Python code
- `android/app/google-services.json` (contains no private keys, just project config)
- `lib/firebase_options.dart` (same — public config only)
- `render.yaml`
- `pubspec.yaml`, `requirements.txt`

Never commit:
- `backend/.env`
- `backend/serviceAccountKey.json`

Both are already in `.gitignore`.

