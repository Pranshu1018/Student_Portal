# Admin Backend Setup Guide

This guide covers setting up the new admin backend for content scraping and AI quiz generation.

## Quick Start

### 1. Install Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### 2. Environment Setup
```bash
cp .env.example .env
```

Edit `.env` with your credentials:
- `FIREBASE_SERVICE_ACCOUNT_JSON`: Your Firebase service account key
- `ANTHROPIC_API_KEY`: Your Claude API key for quiz generation

### 3. Firebase Setup
1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate a new private key
3. Copy the JSON content to `FIREBASE_SERVICE_ACCOUNT_JSON` environment variable
4. Set up Firestore security rules using `firestore.rules`

### 4. Run Admin Server
```bash
python admin_main.py
```

## New Admin API Endpoints

### Create Topic
```http
POST /admin/createTopic
{
  "title": "Data Structures",
  "description": "Learn fundamental data structures"
}
```

### Create Subtopic with Auto-Scraping
```http
POST /admin/createSubtopic
{
  "topicId": "topic-uuid-here",
  "title": "Arrays and Strings",
  "sourceUrl": "https://www.geeksforgeeks.org/arrays-in-python/",
  "order": 1
}
```

### Regenerate Quiz
```http
POST /admin/regenerateQuiz/{subtopic_id}
```

## Content Endpoints for Flutter App

### Get All Topics
```http
GET /content/topics
```

### Get Topic Subtopics
```http
GET /content/topics/{topic_id}/subtopics
```

### Get Subtopic Content
```http
GET /content/subtopics/{subtopic_id}/content
```

### Get Subtopic Quiz (without answers)
```http
GET /content/subtopics/{subtopic_id}/quiz
```

## Integration with Existing Backend

The new admin backend (`admin_main.py`) works alongside your existing backend (`main.py`):

- **Existing backend**: Handles user auth, basic content, quizzes with mock data
- **New admin backend**: Handles content scraping, AI quiz generation, Firebase storage

Run both servers simultaneously for full functionality:
```bash
# Terminal 1: Existing backend
python main.py

# Terminal 2: Admin backend  
python admin_main.py
```

## Firebase Security Rules

Apply the provided `firestore.rules` to ensure:
- Admin-only write access to topics/subtopics
- Public read access for authenticated users
- Quiz answers hidden from clients

## Next Steps

1. Set up Firebase and get service account key
2. Get Anthropic API key for Claude
3. Test admin endpoints with Postman/Swagger
4. Update Flutter app to use new content endpoints
5. Deploy both backends for production
