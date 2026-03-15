from fastapi import APIRouter
from core.firebase import db

router = APIRouter(prefix="/content", tags=["content"])

@router.get("/topics")
async def get_topics():
    topics = []
    for doc in db.collection("topics").stream():
        topics.append(doc.to_dict())
    return {"topics": topics}

@router.get("/topics/{topic_id}/subtopics")
async def get_subtopics(topic_id: str):
    subtopics = []
    for doc in db.collection("subtopics").where("topicId", "==", topic_id).stream():
        subtopics.append(doc.to_dict())
    return {"subtopics": subtopics}

@router.get("/subtopics/{subtopic_id}/content")
async def get_subtopic_content(subtopic_id: str):
    content_docs = db.collection("content").where("subtopicId", "==", subtopic_id).stream()
    content_doc = next(content_docs, None)
    if not content_doc:
        return {"content": None}
    
    content = content_doc.to_dict()
    # Don't return scraped text, only cleaned
    return {"content": {
        "contentId": content["contentId"],
        "cleanedText": content["cleanedText"],
        "scrapedAt": content["scrapedAt"]
    }}

@router.get("/subtopics/{subtopic_id}/quiz")
async def get_subtopic_quiz(subtopic_id: str):
    quizzes = []
    for doc in db.collection("quizzes").where("subtopicId", "==", subtopic_id).stream():
        quiz_data = doc.to_dict()
        # Remove correct answer for client
        quiz_data_without_answer = {k: v for k, v in quiz_data.items() if k != "correctAnswer"}
        quizzes.append(quiz_data_without_answer)
    return {"quizzes": quizzes}
