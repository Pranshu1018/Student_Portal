from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from typing import Optional, List
import jwt
from datetime import datetime, timedelta
import hashlib
import os
import re
from dotenv import load_dotenv
import logging

log = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")

_here = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(_here, ".env"))

# Ensure Firebase path is absolute for local dev
if not os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON"):
    _sa = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "serviceAccountKey.json")
    if not os.path.isabs(_sa):
        os.environ["FIREBASE_SERVICE_ACCOUNT_PATH"] = os.path.join(_here, _sa)

# Initialize FastAPI app
app = FastAPI(title="Student Learning Portal API")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

security = HTTPBearer()

# In-memory database (replace with actual database in production)
users_db = []
subjects_db = [
    {"id": 1, "name": "DSA"},
    {"id": 2, "name": "DBMS"},
    {"id": 3, "name": "OS"},
    {"id": 4, "name": "CN"},
    {"id": 5, "name": "Python"},
    {"id": 6, "name": "Java"},
]

# Sample topics with real content
topics_db = [
    # DSA Topics
    {
        "id": 1,
        "subject_id": 1,
        "title": "Arrays and Strings",
        "video_url": "https://youtu.be/AT14lCXuMKI",
        "content": """Arrays are fundamental data structures that store elements in contiguous memory locations. 

Key Concepts:
- Fixed size collection of elements
- O(1) access time using index
- Efficient for sequential access
- Cache-friendly due to contiguous memory

Common Operations:
1. Traversal: O(n)
2. Insertion: O(n) worst case
3. Deletion: O(n) worst case
4. Search: O(n) linear, O(log n) if sorted

Strings are sequences of characters. In most languages, strings are immutable.

Important String Algorithms:
- Pattern matching (KMP, Rabin-Karp)
- String reversal
- Palindrome checking
- Anagram detection"""
    },
    {
        "id": 2,
        "subject_id": 1,
        "title": "Linked Lists",
        "video_url": "https://youtu.be/R9PTBwOzceo",
        "content": """A linked list is a linear data structure where elements are stored in nodes, and each node points to the next node.

Types of Linked Lists:
1. Singly Linked List - Each node points to next
2. Doubly Linked List - Each node points to next and previous
3. Circular Linked List - Last node points to first

Advantages:
- Dynamic size
- Easy insertion/deletion
- No memory wastage

Disadvantages:
- No random access
- Extra memory for pointers
- Not cache-friendly

Time Complexities:
- Access: O(n)
- Search: O(n)
- Insertion: O(1) if position known
- Deletion: O(1) if position known"""
    },
    {
        "id": 3,
        "subject_id": 1,
        "title": "Stacks and Queues",
        "video_url": "https://youtu.be/wjI1WNcIntg",
        "content": """Stack: LIFO (Last In First Out) data structure

Operations:
- Push: Add element to top - O(1)
- Pop: Remove element from top - O(1)
- Peek: View top element - O(1)

Applications:
- Function call stack
- Expression evaluation
- Backtracking algorithms
- Undo operations

Queue: FIFO (First In First Out) data structure

Operations:
- Enqueue: Add element to rear - O(1)
- Dequeue: Remove element from front - O(1)
- Front: View front element - O(1)

Types:
- Simple Queue
- Circular Queue
- Priority Queue
- Deque (Double-ended queue)

Applications:
- CPU scheduling
- Breadth-first search
- Print queue management"""
    },
    # Python Topics
    {
        "id": 4,
        "subject_id": 5,
        "title": "Python Basics",
        "video_url": "https://youtu.be/rfscVS0vtbw",
        "content": """Python is a high-level, interpreted programming language known for its simplicity and readability.

Key Features:
- Easy to learn and read
- Dynamically typed
- Extensive standard library
- Cross-platform
- Object-oriented and functional programming support

Basic Syntax:
```python
# Variables
name = "Student"
age = 20

# Data Types
integer = 10
float_num = 10.5
string = "Hello"
boolean = True
list_data = [1, 2, 3]
tuple_data = (1, 2, 3)
dict_data = {"key": "value"}

# Control Flow
if age > 18:
    print("Adult")
else:
    print("Minor")

# Loops
for i in range(5):
    print(i)

while condition:
    # code
    pass
```

Functions:
```python
def greet(name):
    return f"Hello, {name}!"
```"""
    },
    {
        "id": 5,
        "subject_id": 5,
        "title": "Object-Oriented Programming",
        "video_url": "https://youtu.be/Ej_02ICOIgs",
        "content": """OOP in Python allows you to create classes and objects.

Core Concepts:
1. Classes and Objects
2. Encapsulation
3. Inheritance
4. Polymorphism
5. Abstraction

Example:
```python
class Student:
    def __init__(self, name, age):
        self.name = name
        self.age = age
    
    def study(self):
        print(f"{self.name} is studying")

# Create object
student1 = Student("John", 20)
student1.study()
```

Inheritance:
```python
class Person:
    def __init__(self, name):
        self.name = name

class Student(Person):
    def __init__(self, name, grade):
        super().__init__(name)
        self.grade = grade
```"""
    },
    # DBMS Topics
    {
        "id": 6,
        "subject_id": 2,
        "title": "Introduction to DBMS",
        "video_url": "https://youtu.be/c5HAwKX-suM",
        "content": """A Database Management System (DBMS) is software that manages databases.

Key Concepts:
- Data: Raw facts
- Database: Organized collection of data
- DBMS: Software to manage databases

Advantages:
1. Data independence
2. Efficient data access
3. Data integrity and security
4. Concurrent access
5. Backup and recovery

Types of DBMS:
1. Relational (MySQL, PostgreSQL)
2. NoSQL (MongoDB, Cassandra)
3. Object-oriented
4. Hierarchical

ACID Properties:
- Atomicity: All or nothing
- Consistency: Valid state transitions
- Isolation: Concurrent transactions
- Durability: Permanent changes"""
    },
]

# Sample questions for quizzes
questions_db = [
    # DSA - Arrays Questions
    {
        "id": 1,
        "topic_id": 1,
        "question_text": "What is the time complexity of accessing an element in an array by index?",
        "option_a": "O(1)",
        "option_b": "O(n)",
        "option_c": "O(log n)",
        "option_d": "O(n²)",
        "correct_answer": "A",
        "subtopic": "Array Basics"
    },
    {
        "id": 2,
        "topic_id": 1,
        "question_text": "Which of the following is true about arrays?",
        "option_a": "Arrays have dynamic size",
        "option_b": "Arrays store elements in contiguous memory",
        "option_c": "Arrays cannot store primitive types",
        "option_d": "Arrays are always sorted",
        "correct_answer": "B",
        "subtopic": "Array Properties"
    },
    {
        "id": 3,
        "topic_id": 1,
        "question_text": "What is the worst-case time complexity for inserting an element at the beginning of an array?",
        "option_a": "O(1)",
        "option_b": "O(log n)",
        "option_c": "O(n)",
        "option_d": "O(n log n)",
        "correct_answer": "C",
        "subtopic": "Array Operations"
    },
    # More questions for variety
    {
        "id": 4,
        "topic_id": 1,
        "question_text": "Which algorithm is used for pattern matching in strings?",
        "option_a": "Binary Search",
        "option_b": "KMP Algorithm",
        "option_c": "Bubble Sort",
        "option_d": "Merge Sort",
        "correct_answer": "B",
        "subtopic": "String Algorithms"
    },
    {
        "id": 5,
        "topic_id": 1,
        "question_text": "What is a palindrome?",
        "option_a": "A string that reads the same forwards and backwards",
        "option_b": "A sorted string",
        "option_c": "A string with unique characters",
        "option_d": "A string with even length",
        "correct_answer": "A",
        "subtopic": "String Concepts"
    },
    # Linked List Questions
    {
        "id": 6,
        "topic_id": 2,
        "question_text": "What is the main advantage of a linked list over an array?",
        "option_a": "Faster access time",
        "option_b": "Dynamic size",
        "option_c": "Less memory usage",
        "option_d": "Better cache performance",
        "correct_answer": "B",
        "subtopic": "Linked List Basics"
    },
    {
        "id": 7,
        "topic_id": 2,
        "question_text": "In a doubly linked list, each node contains:",
        "option_a": "Only data",
        "option_b": "Data and one pointer",
        "option_c": "Data and two pointers",
        "option_d": "Only pointers",
        "correct_answer": "C",
        "subtopic": "Doubly Linked List"
    },
    # Stack Questions
    {
        "id": 8,
        "topic_id": 3,
        "question_text": "Which principle does a stack follow?",
        "option_a": "FIFO",
        "option_b": "LIFO",
        "option_c": "Random access",
        "option_d": "Priority-based",
        "correct_answer": "B",
        "subtopic": "Stack Basics"
    },
    {
        "id": 9,
        "topic_id": 3,
        "question_text": "Which of the following uses a stack?",
        "option_a": "BFS traversal",
        "option_b": "Function call management",
        "option_c": "Print queue",
        "option_d": "Round-robin scheduling",
        "correct_answer": "B",
        "subtopic": "Stack Applications"
    },
    {
        "id": 10,
        "topic_id": 3,
        "question_text": "What principle does a queue follow?",
        "option_a": "LIFO",
        "option_b": "FIFO",
        "option_c": "LILO",
        "option_d": "Random",
        "correct_answer": "B",
        "subtopic": "Queue Basics"
    },
    # Python Questions
    {
        "id": 11,
        "topic_id": 4,
        "question_text": "Which of the following is a mutable data type in Python?",
        "option_a": "Tuple",
        "option_b": "String",
        "option_c": "List",
        "option_d": "Integer",
        "correct_answer": "C",
        "subtopic": "Python Data Types"
    },
    {
        "id": 12,
        "topic_id": 4,
        "question_text": "What is the output of: print(type([]))?",
        "option_a": "<class 'tuple'>",
        "option_b": "<class 'list'>",
        "option_c": "<class 'dict'>",
        "option_d": "<class 'set'>",
        "correct_answer": "B",
        "subtopic": "Python Basics"
    },
    # OOP Questions
    {
        "id": 13,
        "topic_id": 5,
        "question_text": "Which OOP concept is used to hide internal details?",
        "option_a": "Inheritance",
        "option_b": "Polymorphism",
        "option_c": "Encapsulation",
        "option_d": "Abstraction",
        "correct_answer": "C",
        "subtopic": "OOP Concepts"
    },
    {
        "id": 14,
        "topic_id": 5,
        "question_text": "What is the purpose of __init__ in Python?",
        "option_a": "To delete an object",
        "option_b": "To initialize an object",
        "option_c": "To copy an object",
        "option_d": "To compare objects",
        "correct_answer": "B",
        "subtopic": "Python Classes"
    },
    # DBMS Questions
    {
        "id": 15,
        "topic_id": 6,
        "question_text": "What does ACID stand for in DBMS?",
        "option_a": "Atomicity, Consistency, Isolation, Durability",
        "option_b": "Access, Control, Integrity, Data",
        "option_c": "Atomic, Concurrent, Independent, Durable",
        "option_d": "All, Consistent, Isolated, Data",
        "correct_answer": "A",
        "subtopic": "DBMS Properties"
    },
]

quiz_sessions_db = []
performance_db = []
weak_subtopics_db = []

# Pydantic Models
class UserRegister(BaseModel):
    name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class User(BaseModel):
    id: int
    name: str
    email: str
    role: str

class Subject(BaseModel):
    id: int
    name: str

class Topic(BaseModel):
    id: int
    subject_id: int
    title: str
    video_url: Optional[str] = None
    content: str

# Helper Functions
def hash_password(password: str) -> str:
    """Hash password using SHA256 (simple but secure for demo)"""
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash"""
    return hash_password(plain_password) == hashed_password

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("user_id")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

# Routes
@app.get("/")
def read_root():
    return {"message": "Student Learning Portal API", "version": "1.0.0"}

# Authentication Endpoints
@app.post("/api/auth/register")
def register(user: UserRegister):
    # Check if user already exists
    if any(u["email"] == user.email for u in users_db):
        return {"success": False, "message": "Email already registered"}
    
    # Create new user
    new_user = {
        "id": len(users_db) + 1,
        "name": user.name,
        "email": user.email,
        "password_hash": hash_password(user.password),
        "role": "student"
    }
    users_db.append(new_user)
    
    return {
        "success": True,
        "message": "Registration successful",
        "user_id": new_user["id"]
    }

@app.post("/api/auth/login")
def login(credentials: UserLogin):
    # Find user
    user = next((u for u in users_db if u["email"] == credentials.email), None)
    
    if not user or not verify_password(credentials.password, user["password_hash"]):
        return {"success": False, "message": "Invalid email or password"}
    
    # Create token
    token = create_access_token({
        "user_id": user["id"],
        "role": user["role"]
    })
    
    return {
        "success": True,
        "token": token,
        "user": {
            "id": user["id"],
            "name": user["name"],
            "email": user["email"],
            "role": user["role"]
        }
    }

@app.get("/api/auth/verify")
def verify(payload: dict = Depends(verify_token)):
    user = next((u for u in users_db if u["id"] == payload["user_id"]), None)
    
    if not user:
        return {"valid": False}
    
    return {
        "valid": True,
        "user": {
            "id": user["id"],
            "name": user["name"],
            "email": user["email"],
            "role": user["role"]
        }
    }

# Content Endpoints
@app.get("/api/subjects")
def get_subjects(payload: dict = Depends(verify_token)):
    return {"subjects": subjects_db}

@app.get("/api/subjects/{subject_id}/topics")
def get_topics(subject_id: int, payload: dict = Depends(verify_token)):
    # Filter topics by subject_id
    subject_topics = [t for t in topics_db if t["subject_id"] == subject_id]
    return {"topics": subject_topics}

@app.get("/api/topics/{topic_id}")
def get_topic_detail(topic_id: int, payload: dict = Depends(verify_token)):
    topic = next((t for t in topics_db if t["id"] == topic_id), None)
    
    if not topic:
        raise HTTPException(status_code=404, detail="Topic not found")
    
    return topic

# Admin Endpoints (for adding sample data)
@app.post("/api/admin/topics")
def create_topic(
    subject_id: int,
    title: str,
    video_url: Optional[str] = None,
    content: str = "",
    payload: dict = Depends(verify_token)
):
    if payload.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    new_topic = {
        "id": len(topics_db) + 1,
        "subject_id": subject_id,
        "title": title,
        "video_url": video_url,
        "content": content
    }
    topics_db.append(new_topic)
    
    return {"success": True, "topic_id": new_topic["id"]}

# Quiz Endpoints
class QuizStartRequest(BaseModel):
    topic_id: int

@app.post("/api/quiz/start")
def start_quiz(request: QuizStartRequest, payload: dict = Depends(verify_token)):
    import random
    import uuid
    
    topic_id = request.topic_id
    
    # Get questions for this topic
    topic_questions = [q for q in questions_db if q["topic_id"] == topic_id]
    
    if len(topic_questions) < 10:
        # If less than 10 questions, return all
        selected_questions = topic_questions
    else:
        # Randomly select 10 questions
        selected_questions = random.sample(topic_questions, 10)
    
    # Create quiz session
    quiz_id = str(uuid.uuid4())
    quiz_session = {
        "id": quiz_id,
        "user_id": payload["user_id"],
        "topic_id": topic_id,
        "question_ids": [q["id"] for q in selected_questions],
        "started_at": datetime.utcnow().isoformat()
    }
    quiz_sessions_db.append(quiz_session)
    
    # Return questions without correct answers
    questions_response = [
        {
            "id": q["id"],
            "question_text": q["question_text"],
            "option_a": q["option_a"],
            "option_b": q["option_b"],
            "option_c": q["option_c"],
            "option_d": q["option_d"],
        }
        for q in selected_questions
    ]
    
    return {
        "quiz_id": quiz_id,
        "questions": questions_response
    }

class QuizSubmitRequest(BaseModel):
    quiz_id: str
    answers: List[dict]

@app.post("/api/quiz/submit")
def submit_quiz(
    request: QuizSubmitRequest,
    payload: dict = Depends(verify_token)
):
    quiz_id = request.quiz_id
    answers = request.answers
    
    # Find quiz session
    quiz_session = next((q for q in quiz_sessions_db if q["id"] == quiz_id), None)
    if not quiz_session:
        raise HTTPException(status_code=404, detail="Quiz session not found")
    
    # Evaluate answers
    correct_count = 0
    wrong_count = 0
    details = []
    weak_subtopics = {}
    
    for answer in answers:
        question_id = answer["question_id"]
        selected_answer = answer["selected_answer"]
        
        # Find the question
        question = next((q for q in questions_db if q["id"] == question_id), None)
        if not question:
            continue
        
        is_correct = question["correct_answer"] == selected_answer
        
        if is_correct:
            correct_count += 1
        else:
            wrong_count += 1
            # Track weak subtopic
            subtopic = question["subtopic"]
            weak_subtopics[subtopic] = weak_subtopics.get(subtopic, 0) + 1
        
        details.append({
            "question_id": question_id,
            "correct": is_correct,
            "correct_answer": question["correct_answer"],
            "subtopic": question["subtopic"]
        })
    
    # Calculate score
    total_questions = len(answers)
    score = (correct_count / total_questions * 100) if total_questions > 0 else 0
    
    # Update weak subtopics in database
    user_id = payload["user_id"]
    for subtopic, wrong_count_sub in weak_subtopics.items():
        existing = next(
            (w for w in weak_subtopics_db if w["user_id"] == user_id and w["subtopic"] == subtopic),
            None
        )
        if existing:
            existing["weak_score"] += wrong_count_sub
        else:
            weak_subtopics_db.append({
                "id": len(weak_subtopics_db) + 1,
                "user_id": user_id,
                "subtopic": subtopic,
                "weak_score": wrong_count_sub,
                "topic_id": quiz_session["topic_id"]
            })
    
    # Save performance
    performance_db.append({
        "id": len(performance_db) + 1,
        "user_id": user_id,
        "topic_id": quiz_session["topic_id"],
        "quiz_session_id": quiz_id,
        "correct_count": correct_count,
        "wrong_count": wrong_count,
        "score": score,
        "completed_at": datetime.utcnow().isoformat()
    })
    
    # Get weak subtopics with threshold
    weak_subtopics_list = [
        subtopic for subtopic, count in weak_subtopics.items() if count >= 2
    ]
    
    return {
        "score": round(score, 2),
        "correct_count": correct_count,
        "wrong_count": wrong_count,
        "weak_subtopics": weak_subtopics_list,
        "details": details
    }

# Performance Endpoints
@app.get("/api/performance/dashboard")
def get_dashboard(payload: dict = Depends(verify_token)):
    user_id = payload["user_id"]
    
    # Get user's performance
    user_performance = [p for p in performance_db if p["user_id"] == user_id]
    
    if not user_performance:
        return {
            "overall_accuracy": 0,
            "average_score": 0,
            "total_quizzes": 0,
            "weak_subtopics": [],
            "recent_activity": []
        }
    
    # Calculate metrics
    total_quizzes = len(user_performance)
    total_correct = sum(p["correct_count"] for p in user_performance)
    total_questions = sum(p["correct_count"] + p["wrong_count"] for p in user_performance)
    overall_accuracy = (total_correct / total_questions * 100) if total_questions > 0 else 0
    average_score = sum(p["score"] for p in user_performance) / total_quizzes
    
    # Get weak subtopics
    user_weak = [w for w in weak_subtopics_db if w["user_id"] == user_id and w["weak_score"] >= 3]
    weak_subtopics = [
        {
            "subtopic": w["subtopic"],
            "weak_score": w["weak_score"],
            "topic_name": next((t["title"] for t in topics_db if t["id"] == w["topic_id"]), "Unknown")
        }
        for w in user_weak
    ]
    
    # Recent activity
    recent = sorted(user_performance, key=lambda x: x["completed_at"], reverse=True)[:5]
    recent_activity = [
        {
            "type": "quiz",
            "topic": next((t["title"] for t in topics_db if t["id"] == p["topic_id"]), "Unknown"),
            "score": p["score"],
            "timestamp": p["completed_at"]
        }
        for p in recent
    ]
    
    return {
        "overall_accuracy": round(overall_accuracy, 2),
        "average_score": round(average_score, 2),
        "total_quizzes": total_quizzes,
        "weak_subtopics": weak_subtopics,
        "recent_activity": recent_activity
    }

# Web Scraping Endpoint (legacy — kept for compatibility)
@app.post("/api/admin/scrape")
def scrape_content_endpoint(
    url: str,
    topic_id: Optional[int] = None,
    payload: dict = Depends(verify_token)
):
    if payload.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    try:
        from services.scraper_service import ContentScraper
        scraper = ContentScraper()
        result = scraper.scrape(url)
        cleaned = result.cleaned_markdown
        if not cleaned:
            return {"success": False, "message": "Failed to scrape content from URL"}
        if topic_id:
            topic = next((t for t in topics_db if t["id"] == topic_id), None)
            if topic:
                topic["content"] = cleaned
        return {"success": True, "content": cleaned[:500] + "...", "content_length": len(cleaned)}
    except Exception as e:
        return {"success": False, "message": str(e)}

class ScrapeTopicRequest(BaseModel):
    topic_id: str
    url: str

class AutoFetchNotesRequest(BaseModel):
    topic_title: str
    subject: Optional[str] = ""

class DiscoverUrlsRequest(BaseModel):
    topic_name: str

@app.post("/api/admin/discoverUrls")
def discover_urls(body: DiscoverUrlsRequest):
    """Admin: auto-discover GFG + TutorialsPoint URLs for a topic name."""
    try:
        from services.scraper_service import TopicContentPipeline
        pipeline = TopicContentPipeline()
        urls = pipeline.discover_urls(body.topic_name)
        return {
            "success": True,
            "topic_name": urls.topic_name,
            "gfg_url": urls.gfg_url,
            "tp_url": urls.tp_url,
            "has_any": urls.has_any(),
        }
    except Exception as e:
        import traceback
        return {"success": False, "message": str(e), "detail": traceback.format_exc()}

@app.get("/api/topics/{topic_id}/quiz")
async def get_live_quiz(topic_id: str, count: int = 10):
    """Generate MCQ questions using Together AI, cache in Firestore.
    Falls back to cached questions if AI generation fails.
    """
    try:
        from core.firebase import db
        from services.quiz_generator import LiveQuizGenerator

        # 1. Load topic from Firestore
        topic_doc = db.collection("topics").document(topic_id).get()
        if not topic_doc.exists:
            raise HTTPException(status_code=404, detail="Topic not found")

        topic_data = topic_doc.to_dict()
        topic_name = topic_data.get("title", "")
        content = topic_data.get("content", "")

        # 2. Try to generate fresh questions via AI
        questions = []
        if content and len(content.strip()) >= 100:
            try:
                quiz_gen = LiveQuizGenerator()
                questions = quiz_gen.generate(content=content, topic_name=topic_name, count=count)
                # 3. Store generated questions in Firestore for future fallback
                if questions:
                    db.collection("topics").document(topic_id).update({
                        "cached_quiz": questions,
                        "quiz_generated_at": __import__("datetime").datetime.utcnow().isoformat(),
                    })
            except Exception as e:
                log.warning(f"AI generation failed: {e} — will try cache")

        # 4. Fallback: load cached questions from Firestore
        if not questions:
            cached = topic_data.get("cached_quiz", [])
            if cached:
                log.info(f"Using cached quiz for topic {topic_id} ({len(cached)} questions)")
                questions = cached
            else:
                raise HTTPException(
                    status_code=503,
                    detail="Quiz unavailable — no content or cached questions found"
                )

        return {
            "topicId":   topic_id,
            "topicName": topic_name,
            "count":     len(questions),
            "questions": questions,
        }

    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=f"Error: {e}\n{traceback.format_exc()}")


@app.post("/api/notes/fetch")
def auto_fetch_notes(body: AutoFetchNotesRequest):
    """Fetch notes for a topic — auto-discovers GFG/TP URLs then scrapes live content."""
    try:
        from services.scraper_service import TopicContentPipeline
        pipeline = TopicContentPipeline()

        # Step 1: discover URLs
        urls = pipeline.discover_urls(body.topic_title)
        if not urls.has_any():
            return {"success": False, "message": f"No articles found for '{body.topic_title}'"}

        # Step 2: scrape live content (parallel)
        content = pipeline.fetch_live_content(body.topic_title, urls.gfg_url, urls.tp_url)
        best = content.best_content()

        if best and len(best) > 200:
            return {
                "success": True,
                "content": best,
                "source": urls.gfg_url or urls.tp_url or "",
                "gfg_url": urls.gfg_url,
                "tp_url": urls.tp_url,
            }

        return {"success": False, "message": f"Could not scrape content for '{body.topic_title}'"}

    except Exception as e:
        import traceback
        return {"success": False, "message": str(e), "detail": traceback.format_exc()}

@app.post("/api/admin/scrapeTopicContent")
def scrape_topic_content(body: ScrapeTopicRequest):
    """Admin: scrape a specific URL or topic title."""
    try:
        from services.scraper_service import TopicContentPipeline, ContentScraper
        if body.url.startswith("http"):
            scraper = ContentScraper()
            result = scraper.scrape(body.url)
            cleaned = result.cleaned_markdown
        else:
            pipeline = TopicContentPipeline()
            urls = pipeline.discover_urls(body.url)
            content = pipeline.fetch_live_content(body.url, urls.gfg_url, urls.tp_url)
            cleaned = content.best_content()
        if not cleaned:
            return {"success": False, "message": "Could not fetch content"}
        return {"success": True, "content": cleaned, "content_length": len(cleaned)}
    except Exception as e:
        import traceback
        return {"success": False, "message": str(e), "detail": traceback.format_exc()}


class RefreshVideoRequest(BaseModel):
    topic_id: str

@app.post("/api/admin/findVideo")
def find_video_for_topic(body: RefreshVideoRequest):
    """Find and save an embeddable YouTube video for a topic."""
    try:
        from services.youtube_finder import YouTubeFinder
        from core.firebase import db
        finder = YouTubeFinder()
        video = finder.update_topic_video(body.topic_id, db)
        if not video:
            return {"success": False, "message": "No embeddable video found"}
        return {"success": True, "videoUrl": video["url"], "videoTitle": video["title"]}
    except ValueError as e:
        return {"success": False, "message": str(e)}
    except Exception as e:
        import traceback
        return {"success": False, "message": str(e), "detail": traceback.format_exc()}


@app.post("/api/admin/seedVideos")
def seed_all_videos(subject_id: Optional[int] = None):
    """Bulk-find embeddable YouTube videos for all topics (or one subject)."""
    try:
        from services.youtube_finder import YouTubeFinder
        from core.firebase import db
        finder = YouTubeFinder()
        query = db.collection("topics")
        if subject_id:
            query = query.where("subject_id", "==", subject_id)
        docs = query.get()
        results = []
        for doc in docs:
            data = doc.to_dict()
            if data.get("video_url"):
                results.append({"id": doc.id, "status": "skipped (already has video)"})
                continue
            video = finder.update_topic_video(doc.id, db)
            results.append({
                "id": doc.id,
                "title": data.get("title", ""),
                "status": "updated" if video else "not found",
                "videoUrl": video["url"] if video else None,
            })
        return {"success": True, "results": results}
    except ValueError as e:
        return {"success": False, "message": str(e)}
    except Exception as e:
        import traceback
        return {"success": False, "message": str(e), "detail": traceback.format_exc()}

# Code Execution Endpoint with Judge0 Integration
@app.post("/api/code/execute")
async def execute_code(
    code: str,
    language: str,
    test_cases: List[dict],
    payload: dict = Depends(verify_token)
):
    """Execute code using Judge0 API"""
    import requests
    import time
    
    # Language ID mapping for Judge0
    language_ids = {
        'python': 71,      # Python 3.8.1
        'java': 62,        # Java (OpenJDK 13.0.1)
        'cpp': 54,         # C++ (GCC 9.2.0)
        'c': 50,           # C (GCC 9.2.0)
        'javascript': 63   # JavaScript (Node.js 12.14.0)
    }
    
    language_id = language_ids.get(language.lower(), 71)
    
    try:
        # Get input from first test case if available
        stdin_input = test_cases[0]['input'] if test_cases and 'input' in test_cases[0] else ""
        
        # Format request for Judge0
        submission = {
            "source_code": code,
            "language_id": language_id,
            "stdin": stdin_input,
        }
        
        # Judge0 CE API endpoint (free hosted version)
        # For production, use your own Judge0 instance or RapidAPI
        judge0_url = "https://judge0-ce.p.rapidapi.com/submissions"
        
        # Try to get API key from environment, fallback to demo mode
        rapidapi_key = os.getenv("RAPIDAPI_KEY", None)
        
        if rapidapi_key:
            # Use RapidAPI hosted Judge0
            headers = {
                "content-type": "application/json",
                "X-RapidAPI-Key": rapidapi_key,
                "X-RapidAPI-Host": "judge0-ce.p.rapidapi.com"
            }
            
            # Create submission
            response = requests.post(
                judge0_url,
                json=submission,
                headers=headers,
                params={"base64_encoded": "false", "wait": "false"}
            )
            
            if response.status_code != 201:
                return {
                    "success": False,
                    "results": [{
                        "test_case_id": 0,
                        "passed": False,
                        "actual_output": "",
                        "error": f"Submission failed: {response.text}"
                    }],
                    "execution_time": 0
                }
            
            # Get submission token
            token = response.json()['token']
            
            # Poll for result (max 10 attempts)
            for _ in range(10):
                time.sleep(1)
                
                result_response = requests.get(
                    f"{judge0_url}/{token}",
                    headers=headers,
                    params={"base64_encoded": "false"}
                )
                
                result = result_response.json()
                
                # Check if processing is complete
                if result['status']['id'] not in [1, 2]:  # 1=In Queue, 2=Processing
                    break
            
            # Process result
            status_id = result['status']['id']
            stdout = result.get('stdout', '').strip()
            stderr = result.get('stderr', '').strip()
            compile_output = result.get('compile_output', '').strip()
            
            # Status codes: 3=Accepted, 4=Wrong Answer, 5=Time Limit, 6=Compilation Error, etc.
            success = status_id == 3
            
            error_message = None
            if compile_output:
                error_message = f"Compilation Error:\n{compile_output}"
            elif stderr:
                error_message = f"Runtime Error:\n{stderr}"
            elif status_id == 5:
                error_message = "Time Limit Exceeded"
            elif status_id == 6:
                error_message = "Compilation Error"
            elif status_id == 11:
                error_message = "Runtime Error (SIGSEGV)"
            elif status_id == 12:
                error_message = "Runtime Error (SIGXFSZ)"
            elif status_id == 13:
                error_message = "Runtime Error (SIGFPE)"
            elif status_id == 14:
                error_message = "Runtime Error (SIGABRT)"
            
            return {
                "success": success,
                "results": [{
                    "test_case_id": 0,
                    "passed": success,
                    "actual_output": stdout if stdout else (error_message or "No output"),
                    "error": error_message
                }],
                "execution_time": result.get('time', 0)
            }
        
        else:
            # Demo mode - simulate execution without actual Judge0 API
            return {
                "success": True,
                "results": [{
                    "test_case_id": 0,
                    "passed": True,
                    "actual_output": "Demo Mode: Code execution requires Judge0 API key.\n\nTo enable real code execution:\n1. Get a free API key from RapidAPI (Judge0 CE)\n2. Set RAPIDAPI_KEY environment variable\n3. Restart the backend\n\nYour code:\n" + code[:200] + ("..." if len(code) > 200 else ""),
                    "error": None
                }],
                "execution_time": 0
            }
    
    except Exception as e:
        return {
            "success": False,
            "results": [{
                "test_case_id": 0,
                "passed": False,
                "actual_output": "",
                "error": f"Execution error: {str(e)}"
            }],
            "execution_time": 0
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
