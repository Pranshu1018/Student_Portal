# Student Learning Portal

A comprehensive mobile learning platform built with Flutter and Python FastAPI.

## Features

### Phase 1 (Current Implementation)
- ✅ User Authentication (Login/Register)
- ✅ JWT Token Management
- ✅ Subject Browsing
- ✅ Topic Listing
- ✅ Content Display with Video Player
- ✅ Modern, Clean UI with Gradient Themes

### Upcoming Phases
- **Phase 2**: Quiz System, Random Question Logic, Weakness Tracking
- **Phase 3**: Code Editor, Judge0 Integration
- **Phase 4**: Analytics Dashboard, Admin Panel

## Tech Stack

### Frontend (Flutter)
- **State Management**: Riverpod
- **HTTP Client**: http package
- **Secure Storage**: flutter_secure_storage
- **Video Player**: youtube_player_flutter
- **Charts**: fl_chart (for analytics)

### Backend (Python)
- **Framework**: FastAPI
- **Authentication**: JWT with PyJWT
- **Password Hashing**: Passlib with bcrypt
- **Database**: In-memory (Phase 1) → PostgreSQL (Production)

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Python 3.8+
- Android Studio / VS Code
- Android Emulator or Physical Device

### Flutter App Setup

1. **Install Dependencies**
```bash
flutter pub get
```

2. **Update API Base URL**
Edit `lib/core/constants/api_constants.dart`:
```dart
static const String baseUrl = 'http://YOUR_IP:8000/api';
```
For Android Emulator, use: `http://10.0.2.2:8000/api`
For Physical Device, use your computer's IP address

3. **Run the App**
```bash
flutter run
```

### Backend Setup

1. **Navigate to Backend Directory**
```bash
cd backend
```

2. **Install Python Dependencies**
```bash
pip install -r requirements.txt
```

3. **Run the Server**
```bash
python main.py
```

The API will be available at `http://localhost:8000`

4. **View API Documentation**
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Project Structure

```
student_portal/
├── lib/
│   ├── core/
│   │   └── constants/
│   │       ├── app_colors.dart
│   │       └── api_constants.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── subject_model.dart
│   │   └── topic_model.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   └── content_provider.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   └── subjects/
│   │       ├── subjects_screen.dart
│   │       ├── topics_screen.dart
│   │       └── topic_detail_screen.dart
│   ├── services/
│   │   └── api_service.dart
│   └── main.dart
├── backend/
│   ├── main.py
│   ├── requirements.txt
│   └── README.md
└── README.md
```

## UI Design

The app features a modern, gradient-based design with:
- **Primary Colors**: Blue (#6C63FF) and Purple (#9D4EDD)
- **Clean Cards**: Rounded corners with subtle shadows
- **Smooth Gradients**: Eye-catching color transitions
- **Intuitive Navigation**: Easy-to-use interface

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login and get JWT token
- `GET /api/auth/verify` - Verify JWT token

### Content
- `GET /api/subjects` - Get all subjects (DSA, DBMS, OS, CN, Python, Java)
- `GET /api/subjects/{subject_id}/topics` - Get topics for a subject
- `GET /api/topics/{topic_id}` - Get topic details with video and content

## Development Roadmap

### Phase 1: Authentication & Content ✅
- User registration and login
- Subject and topic browsing
- Video and article content display

### Phase 2: Quiz System (Next)
- Random question selection (10 from 30)
- Quiz taking interface
- Weakness detection and tracking
- Performance analytics

### Phase 3: Code Editor
- In-app code editor with syntax highlighting
- Judge0 API integration
- Multi-language support (C, C++, Java, Python, JS)
- Test case execution

### Phase 4: Advanced Features
- Analytics dashboard with charts
- Admin panel for content management
- Leaderboard
- Daily streaks
- Bookmarks and notes

## Contributing

This is a learning project. Feel free to fork and enhance!

## Support

For issues or questions, please create an issue in the repository.
