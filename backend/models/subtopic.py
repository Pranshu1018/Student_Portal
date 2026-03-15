from pydantic import BaseModel
from typing import Optional

class SubtopicCreate(BaseModel):
    topicId: str
    title: str
    sourceUrl: str
    order: Optional[int] = 0
