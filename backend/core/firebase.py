import firebase_admin
from firebase_admin import credentials, firestore, auth
import os
import json

# Support both a JSON file path and inline JSON in env var
_sa = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
_sa_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "")

if _sa_path and os.path.exists(_sa_path):
    cred = credentials.Certificate(_sa_path)
elif _sa.strip().startswith("{"):
    cred = credentials.Certificate(json.loads(_sa))
else:
    # Fall back to looking for serviceAccountKey.json next to this file
    _default = os.path.join(os.path.dirname(__file__), "..", "serviceAccountKey.json")
    cred = credentials.Certificate(os.path.abspath(_default))

firebase_admin.initialize_app(cred)
db = firestore.client()
