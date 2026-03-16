"""
seed_videos.py
──────────────
Run this once to find embeddable YouTube videos for all topics
and save them directly to Firestore.

Usage:
    cd backend
    python seed_videos.py
"""
import os
import sys
import time

_here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _here)

# Load .env first
from dotenv import load_dotenv
load_dotenv(os.path.join(_here, ".env"))

# Explicitly set the path so firebase.py can find it
if not os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON"):
    os.environ["FIREBASE_SERVICE_ACCOUNT_PATH"] = os.path.join(_here, "serviceAccountKey.json")

# Now safe to import Firebase-dependent modules
from core.firebase import db
from services.youtube_finder import YouTubeFinder

finder = YouTubeFinder()

def seed_all():
    docs = list(db.collection("topics").get())
    total = len(docs)
    print(f"\n{'='*60}")
    print(f"  Seeding YouTube videos for {total} topics")
    print(f"{'='*60}\n")

    updated = 0
    skipped = 0
    failed  = 0

    for i, doc in enumerate(docs, 1):
        data     = doc.to_dict()
        topic_id = doc.id
        title    = data.get("title", f"Topic {topic_id}")

        # Skip if already has a video URL
        if data.get("video_url"):
            print(f"[{i:>3}/{total}] SKIP  {title[:45]} (already has video)")
            skipped += 1
            continue

        print(f"[{i:>3}/{total}] Searching: {title[:45]}...", end=" ", flush=True)
        video = finder.find_embeddable_video(title)

        if video:
            db.collection("topics").document(topic_id).update({
                "video_url": video["url"],
            })
            print(f"✓  {video['title'][:40]}")
            updated += 1
        else:
            print("✗  not found")
            failed += 1

        # Small delay to avoid hitting rate limits
        time.sleep(0.5)

    print(f"\n{'='*60}")
    print(f"  Done — {updated} updated, {skipped} skipped, {failed} not found")
    print(f"{'='*60}\n")

if __name__ == "__main__":
    seed_all()
