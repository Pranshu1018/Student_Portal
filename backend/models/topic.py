from pydantic import BaseModel
from typing import Optional

class TopicCreate(BaseModel):
    title: str
    description: str

class SubtopicCreate(BaseModel):
    topicId: str
    title: str
    sourceUrl: str
    order: Optional[int] = 0
