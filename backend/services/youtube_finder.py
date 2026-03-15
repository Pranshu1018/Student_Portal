"""
youtube_finder.py
─────────────────
Finds embeddable YouTube videos for topic names using YouTube Data API v3.
Filters out error 150/152 (embedding disabled) automatically.
"""
import os
import re
import logging
from typing import Optional
from datetime import datetime

from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

logging.basicConfig(level=logging.INFO, format="%(levelname)s │ %(message)s")
log = logging.getLogger(__name__)


def _duration_seconds(duration: str) -> int:
    """Convert ISO 8601 duration 'PT10M30S' → seconds."""
    if not duration:
        return 0
    h = re.search(r'(\d+)H', duration)
    m = re.search(r'(\d+)M', duration)
    s = re.search(r'(\d+)S', duration)
    return (int(h.group(1)) if h else 0) * 3600 + \
           (int(m.group(1)) if m else 0) * 60 + \
           (int(s.group(1)) if s else 0)


class YouTubeFinder:
    def __init__(self, api_key: Optional[str] = None):
        key = api_key or os.getenv("YOUTUBE_API_KEY")
        if not key:
            raise ValueError("Set YOUTUBE_API_KEY env var")
        self.youtube = build("youtube", "v3", developerKey=key)
        log.info("YouTubeFinder ready")

    def find_embeddable_video(self, topic_name: str, max_candidates: int = 10) -> Optional[dict]:
        """Search YouTube and return first embeddable video for topic_name."""
        query = f"{topic_name} tutorial explained"
        log.info(f"Searching YouTube: '{query}'")
        try:
            search_resp = self.youtube.search().list(
                q=query, part="id,snippet", type="video",
                maxResults=max_candidates, relevanceLanguage="en",
                safeSearch="moderate", videoCategoryId="27",
            ).execute()
            video_ids = [
                item["id"]["videoId"]
                for item in search_resp.get("items", [])
                if item["id"]["kind"] == "youtube#video"
            ]
            if not video_ids:
                return self._fallback_search(topic_name, max_candidates)

            result = self._pick_embeddable(video_ids)
            return result or self._fallback_search(topic_name, max_candidates)
        except HttpError as e:
            log.error(f"YouTube API error: {e}")
            return None

    def _fallback_search(self, topic_name: str, max_candidates: int) -> Optional[dict]:
        try:
            search_resp = self.youtube.search().list(
                q=f"{topic_name} tutorial computer science",
                part="id,snippet", type="video",
                maxResults=max_candidates, relevanceLanguage="en",
            ).execute()
            video_ids = [
                item["id"]["videoId"]
                for item in search_resp.get("items", [])
                if item["id"]["kind"] == "youtube#video"
            ]
            return self._pick_embeddable(video_ids) if video_ids else None
        except HttpError as e:
            log.error(f"Fallback search error: {e}")
            return None

    def _pick_embeddable(self, video_ids: list) -> Optional[dict]:
        videos_resp = self.youtube.videos().list(
            id=",".join(video_ids),
            part="id,snippet,status,contentDetails",
        ).execute()
        for item in videos_resp.get("items", []):
            status = item.get("status", {})
            snippet = item.get("snippet", {})
            details = item.get("contentDetails", {})
            if not status.get("embeddable") or status.get("privacyStatus") != "public":
                continue
            if _duration_seconds(details.get("duration", "PT0S")) < 120:
                continue
            thumbnails = snippet.get("thumbnails", {})
            thumbnail = (thumbnails.get("high", {}).get("url")
                         or thumbnails.get("default", {}).get("url", ""))
            video_id = item["id"]
            log.info(f"  ✓ {video_id} — {snippet.get('title', '')[:50]}")
            return {
                "videoId": video_id,
                "url": f"https://www.youtube.com/watch?v={video_id}",
                "title": snippet.get("title", ""),
                "channelName": snippet.get("channelTitle", ""),
                "duration": details.get("duration", ""),
                "thumbnail": thumbnail,
                "embeddable": True,
            }
        return None

    def update_topic_video(self, topic_id: str, db) -> Optional[dict]:
        """Find video for topic and update its Firestore doc."""
        doc = db.collection("topics").document(topic_id).get()
        if not doc.exists:
            return None
        topic_name = doc.to_dict().get("title", "")
        video = self.find_embeddable_video(topic_name)
        if not video:
            return None
        db.collection("topics").document(topic_id).update({
            "video_url":       video["url"],
            "videoId":         video["videoId"],
            "videoTitle":      video["title"],
            "videoChannel":    video["channelName"],
            "videoThumbnail":  video["thumbnail"],
            "videoDuration":   video["duration"],
            "videoUpdatedAt":  datetime.utcnow(),
        })
        log.info(f"Updated topic '{topic_name}' → {video['url']}")
        return video
