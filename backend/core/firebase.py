import firebase_admin
from firebase_admin import credentials, firestore
import os
import json

# On Render: set FIREBASE_SERVICE_ACCOUNT_JSON env var with the full JSON as a string
# Locally: set FIREBASE_SERVICE_ACCOUNT_PATH pointing to serviceAccountKey.json

_sa_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
_sa_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()

if _sa_json:
    # Render / production: inline JSON string
    cred = credentials.Certificate(json.loads(_sa_json))
elif _sa_path:
    # Local dev: path to JSON file (absolute or relative to backend/)
    if os.path.isabs(_sa_path):
        full_path = _sa_path
    else:
        base = os.path.dirname(__file__)
        full_path = os.path.abspath(os.path.join(base, "..", _sa_path))
    cred = credentials.Certificate(full_path)
else:
    raise ValueError(
        "Firebase credentials not found. "
        "Set FIREBASE_SERVICE_ACCOUNT_JSON (production) "
        "or FIREBASE_SERVICE_ACCOUNT_PATH (local dev)."
    )

firebase_admin.initialize_app(cred)
db = firestore.client()
