"""
FastAPI Backend Application
A production-ready REST API with OpenAI ChatGPT integration
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from openai import OpenAI
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="Fullstack API",
    description="REST API with OpenAI ChatGPT integration",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://localhost:3000",
        "https://speri-008-dev.agents.opsera-labs.com",  # Production URL
        "http://prospectf500-app1-dev.agents.opsera-labs.com",  # Current deployment
        "https://prospectf500-app1-dev.agents.opsera-labs.com",  # HTTPS (when configured)
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory storage for API key and OpenAI client
_app_state = {
    "api_key": None,
    "openai_client": None
}

def get_openai_client():
    """Get or create OpenAI client"""
    # Check in-memory key first, then fall back to env var
    api_key = _app_state["api_key"] or os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="OpenAI API key not configured. Please set it via Admin Settings or OPENAI_API_KEY environment variable."
        )
    # Recreate client if key changed or doesn't exist
    if _app_state["openai_client"] is None or _app_state["api_key"] != api_key:
        _app_state["openai_client"] = OpenAI(api_key=api_key)
        _app_state["api_key"] = api_key
    return _app_state["openai_client"]


class ApiKeyRequest(BaseModel):
    """Request model for setting API key"""
    api_key: str = Field(..., min_length=1)


class ChatRequest(BaseModel):
    """Request model for chat endpoint"""
    message: str = Field(..., min_length=1, max_length=10000)
    model: str = Field(default="gpt-4-turbo-preview")


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to the Fullstack API",
        "status": "healthy",
        "docs": "/docs"
    }


@app.get("/health")
async def health():
    """Health check endpoint for Kubernetes probes"""
    return {"status": "healthy", "service": "speri-008-backend"}


@app.get("/test")
async def test():
    """Test endpoint for connectivity verification"""
    return {
        "status": "success",
        "message": "Backend is running and ready to accept requests!"
    }


@app.get("/admin/api-key/status")
async def get_api_key_status():
    """Check if API key is configured"""
    has_memory_key = _app_state["api_key"] is not None
    has_env_key = os.getenv("OPENAI_API_KEY") is not None
    return {
        "configured": has_memory_key or has_env_key,
        "source": "memory" if has_memory_key else ("environment" if has_env_key else None)
    }


@app.post("/admin/api-key")
async def set_api_key(request: ApiKeyRequest):
    """Set OpenAI API key in memory"""
    _app_state["api_key"] = request.api_key
    _app_state["openai_client"] = None  # Reset client to use new key
    return {
        "status": "success",
        "message": "API key has been set successfully"
    }


@app.delete("/admin/api-key")
async def clear_api_key():
    """Clear the in-memory API key"""
    _app_state["api_key"] = None
    _app_state["openai_client"] = None
    return {
        "status": "success",
        "message": "API key has been cleared"
    }


@app.post("/chat")
async def chat(request: ChatRequest):
    """
    Chat endpoint with OpenAI integration

    Args:
        request: ChatRequest with message and optional model

    Returns:
        AI response with token usage information
    """
    if not request.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    try:
        client = get_openai_client()
        response = client.chat.completions.create(
            model=request.model,
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": request.message}
            ],
            max_tokens=1000
        )

        return {
            "status": "success",
            "response": response.choices[0].message.content,
            "model": request.model,
            "usage": {
                "prompt_tokens": response.usage.prompt_tokens,
                "completion_tokens": response.usage.completion_tokens,
                "total_tokens": response.usage.total_tokens
            }
        }

    except Exception as e:
        error_message = str(e)
        if "invalid_api_key" in error_message.lower():
            raise HTTPException(status_code=401, detail="Invalid OpenAI API key")
        elif "rate_limit" in error_message.lower():
            raise HTTPException(status_code=429, detail="Rate limit exceeded. Please try again later.")
        else:
            raise HTTPException(status_code=500, detail=f"Error processing request: {error_message}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
