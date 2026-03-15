from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import admin, content
from core.firebase import db

app = FastAPI(title="Student Portal Admin API", version="1.0.0")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(admin.router)
app.include_router(content.router)

@app.get("/")
async def root():
    return {"message": "Student Portal Admin API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "database": "connected"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
