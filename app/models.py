# models.py
from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID

class Health(BaseModel):
    status: str
    ray_status: bool
    active_browsers: int

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
    total_cpus: Optional[int]
    available_cpus: Optional[int]
    browsers: List[BrowserStatus]