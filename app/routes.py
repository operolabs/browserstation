# routes.py
import os
from fastapi import APIRouter, WebSocket, HTTPException, Depends
from fastapi.security import APIKeyHeader
from .service import BrowserService

from app.models import Health, ActorInfo, BrowserList, BrowserInfo, BrowserStatus 

router = APIRouter()
service = BrowserService()

# Simple API key from environment variable
API_KEY = os.getenv("BROWSERSTATION_API_KEY")

# API key authentication using FastAPI security
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

async def verify_api_key(api_key: str = Depends(api_key_header)):
    """Verify API key from X-API-Key header"""
    if API_KEY and api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return api_key

@router.get("/", response_model=Health)
async def health():
    """Health check endpoint."""
    return await service.health()

@router.post("/browsers", dependencies=[Depends(verify_api_key)], response_model=ActorInfo)
async def create_browser():
    """Create a new browser instance."""
    return await service.create_browser()

@router.get("/browsers", dependencies=[Depends(verify_api_key)], response_model=BrowserList)
async def list_browsers():
    """List all browser instances and cluster CPU stats."""
    return await service.list_browsers()

@router.get("/browsers/{browser_id}", dependencies=[Depends(verify_api_key)], response_model=BrowserInfo)
async def get_browser(browser_id: str):
    """
    Get information about a specific browser instance.
    
    Args:
        browser_id: UUID of the browser instance
    """
    return await service.get_browser(browser_id)

@router.delete("/browsers/{browser_id}", dependencies=[Depends(verify_api_key)], response_model=BrowserStatus)
async def close_browser(browser_id: str):
    """
    Close and delete a browser instance.
    
    Args:
        browser_id: UUID of the browser instance to close
    """
    return await service.delete_browser(browser_id)

@router.websocket("/ws/browsers/{browser_id}/{path:path}")
async def websocket_proxy(websocket: WebSocket, browser_id: str, path: str):
    """
    WebSocket proxy to Chrome DevTools Protocol.
    
    Args:
        websocket: FastAPI WebSocket connection
        browser_id: UUID of the browser instance
        path: Chrome DevTools path (e.g., "devtools/browser")
    """
    await service.websocket_proxy(websocket, browser_id, path)
