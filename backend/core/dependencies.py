from fastapi import Header, HTTPException
from core.firebase import auth as firebase_auth

async def verify_admin(authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Invalid auth header")
    token = authorization.split(" ")[1]
    try:
        decoded = firebase_auth.verify_id_token(token)
        # Check custom claim set in Firebase Console or Admin SDK
        if not decoded.get("admin"):
            raise HTTPException(403, "Admin access required")
        return decoded
    except Exception:
        raise HTTPException(401, "Token invalid or expired")
