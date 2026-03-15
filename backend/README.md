# Student Learning Portal - Backend

FastAPI backend for the Student Learning Portal mobile app.

## Features

- JWT Authentication
- Subject & Topic Management
- Quiz System with Random Question Selection
- Weakness Detection & Performance Tracking
- Web Scraping (GeeksforGeeks, TutorialsPoint)
- Code Execution with Judge0 API
- Analytics Dashboard

## Setup

### 1. Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Set Environment Variables (Optional)

For production, set a secure secret key:
```bash
export SECRET_KEY="your-secure-secret-key-here"
```

For code execution with Judge0 API (optional):
```bash
export RAPIDAPI_KEY="your-rapidapi-key-here"
```

### 3. Run the Server

```bash
python main.py
```

Or using uvicorn directly:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`

## Getting Judge0 API Key (Optional)

The code execution feature works in demo mode without an API key, but for real code execution:

1. Go to [RapidAPI Judge0 CE](https://rapidapi.com/judge0-official/api/judge0-ce)
2. Sign up for a free account
3. Subscribe to the free tier (100 requests/day)
4. Copy your API key
5. Set the environment variable:
   ```bash
   export RAPIDAPI_KEY="your-key-here"
   ```

## API Documentation

Once the server is running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login and get JWT token
- `GET /api/auth/verify` - Verify JWT token

### Content
- `GET /api/subjects` - Get all subjects
- `GET /api/subjects/{subject_id}/topics` - Get topics for a subject
- `GET /api/topics/{topic_id}` - Get topic details

### Quiz
- `POST /api/quiz/start` - Start a quiz (random 10 questions)
- `POST /api/quiz/submit` - Submit quiz answers

### Performance
- `GET /api/performance/dashboard` - Get user analytics

### Code Execution
- `POST /api/code/execute` - Execute code (supports Python, Java, C++, C, JavaScript)

### Admin
- `POST /api/admin/topics` - Create new topic (admin only)
- `POST /api/admin/scrape` - Scrape content from URL

## Database

Currently using in-memory storage. For production:
- Replace with PostgreSQL/MySQL
- Use SQLAlchemy ORM
- Add proper migrations with Alembic

## Security Notes

- Change `SECRET_KEY` in production
- Use HTTPS in production
- Implement rate limiting
- Add input validation
- Use proper password hashing (bcrypt recommended)

## Web Scraping

The scraper supports:
- GeeksforGeeks
- TutorialsPoint

Usage:
```python
from scraper import ContentScraper

scraper = ContentScraper()
content = scraper.scrape_content("https://www.geeksforgeeks.org/...")
cleaned = scraper.clean_content(content)
```

## Code Execution

Supports 5 languages:
- Python 3
- Java
- C++
- C
- JavaScript (Node.js)

**Demo mode** (no API key):
- Returns mock response with code preview
- Useful for testing UI

**Production mode** (with API key):
- Real code execution via Judge0
- Compilation error detection
- Runtime error handling
- Time limit enforcement

## Testing

Test the API endpoints using the Swagger UI at `http://localhost:8000/docs`

1. Register a user
2. Login to get JWT token
3. Use the token for authenticated requests
4. Try quiz, code execution, and analytics endpoints
