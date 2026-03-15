from fastapi import APIRouter, Depends, BackgroundTasks, HTTPException
from core.dependencies import verify_admin
from core.firebase import db
from services.scraper_service import TopicContentPipeline, ContentScraper
from services.quiz_generator import QuizGenerator
from models.subtopic import SubtopicCreate
from models.topic import TopicCreate
import uuid, os
from datetime import datetime
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/admin", tags=["admin"])
pipeline = TopicContentPipeline()
scraper = ContentScraper()
quiz_gen = QuizGenerator(api_key=os.getenv("ANTHROPIC_API_KEY"))


class ScrapeTopicRequest(BaseModel):
    topic_id: str
    url: str


@router.post("/scrapeTopicContent")
async def scrape_topic_content(body: ScrapeTopicRequest, admin=Depends(verify_admin)):
    """Scrape content from GFG/TutorialsPoint and save to Firestore topics collection."""
    try:
        if body.url.startswith("http"):
            result = scraper.scrape(body.url)
            cleaned = result.cleaned_markdown
        else:
            # treat url field as topic name
            urls = pipeline.discover_urls(body.url)
            content = pipeline.fetch_live_content(body.url, urls.gfg_url, urls.tp_url)
            cleaned = content.best_content()

        if not cleaned:
            raise HTTPException(400, "Could not scrape content")

        db.collection("topics").document(body.topic_id).update({
            "content": cleaned,
            "scraped_at": datetime.utcnow().isoformat(),
        })
        return {"success": True, "content_length": len(cleaned), "preview": cleaned[:300]}
    except PermissionError as e:
        raise HTTPException(403, str(e))
    except ValueError as e:
        raise HTTPException(400, str(e))
    except Exception as e:
        raise HTTPException(500, f"Scrape failed: {str(e)}")



@router.post("/createTopic")
async def create_topic(body: TopicCreate, admin=Depends(verify_admin)):
    topic_id = str(uuid.uuid4())
    doc = {
        "topicId": topic_id,
        "title": body.title,
        "description": body.description,
        "createdBy": admin["uid"],
        "createdAt": datetime.utcnow(),
    }
    db.collection("topics").document(topic_id).set(doc)
    return {"topicId": topic_id, "status": "created"}


@router.post("/createSubtopic")
async def create_subtopic(
    body: SubtopicCreate,
    background_tasks: BackgroundTasks,
    admin=Depends(verify_admin)
):
    subtopic_id = str(uuid.uuid4())
    doc = {
        "subtopicId": subtopic_id,
        "topicId": body.topicId,
        "title": body.title,
        "sourceUrl": body.sourceUrl,
        "scrapeStatus": "pending",
        "order": body.order or 0,
        "createdAt": datetime.utcnow(),
    }
    db.collection("subtopics").document(subtopic_id).set(doc)

    # Kick off scraping as background task — non-blocking
    background_tasks.add_task(_scrape_and_store, subtopic_id, body.sourceUrl)
    return {"subtopicId": subtopic_id, "status": "scraping_started"}


async def _scrape_and_store(subtopic_id: str, url: str):
    ref = db.collection("subtopics").document(subtopic_id)
    try:
        ref.update({"scrapeStatus": "scraping"})

        if url.startswith("http"):
            result = scraper.scrape(url)
            cleaned = result.cleaned_markdown
        else:
            urls = pipeline.discover_urls(url)
            content = pipeline.fetch_live_content(url, urls.gfg_url, urls.tp_url)
            cleaned = content.best_content()

        if not cleaned:
            raise ValueError("Empty content returned")

        content_id = str(uuid.uuid4())
        db.collection("content").document(content_id).set({
            "contentId": content_id,
            "subtopicId": subtopic_id,
            "cleanedText": cleaned,
            "scrapedAt": datetime.utcnow(),
        })

        questions = quiz_gen.generate(cleaned, subtopic_id)
        batch = db.batch()
        for q in questions:
            qid = str(uuid.uuid4())
            q["quizId"] = qid
            batch.set(db.collection("quizzes").document(qid), q)
        batch.commit()

        ref.update({"scrapeStatus": "done"})
    except Exception as e:
        ref.update({"scrapeStatus": "failed", "errorMsg": str(e)})


@router.post("/regenerateQuiz/{subtopic_id}")
async def regenerate_quiz(subtopic_id: str, admin=Depends(verify_admin)):
    # Fetch existing content
    content_docs = db.collection("content").where("subtopicId", "==", subtopic_id).stream()
    content_doc = next(content_docs, None)
    if not content_doc:
        raise HTTPException(404, "No content found for this subtopic")

    cleaned = content_doc.to_dict()["cleanedText"]

    # Delete old quizzes
    old = db.collection("quizzes").where("subtopicId", "==", subtopic_id).stream()
    batch = db.batch()
    for doc in old:
        batch.delete(doc.reference)
    batch.commit()

    # Generate fresh
    questions = quiz_gen.generate(cleaned, subtopic_id)
    batch = db.batch()
    for q in questions:
        qid = str(uuid.uuid4())
        q["quizId"] = qid
        batch.set(db.collection("quizzes").document(qid), q)
    batch.commit()
    return {"regenerated": len(questions)}
