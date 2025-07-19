# models.py
from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID

class Health(BaseModel):
    status: str
    ray_status: bool
    browsers: dict  # {"alive": count, "pending": count, "dead": count}
    cluster: dict   # Ray cluster resources
    available: dict # Ray available resources  

class BrowserInfo(BaseModel):
    browser_id: UUID
    pod_ip: str
    websocket_url: Optional[str] = None
    chrome_ready: bool

class ActorInfo(BaseModel):
    browser_id: UUID
    proxy_url: str

class BrowserStatus(BaseModel):
    browser_id: UUID
    status: str

class BrowserList(BaseModel):
    browsers: List[dict] 