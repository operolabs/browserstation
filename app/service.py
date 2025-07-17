# service.py
import uuid
import ray
from ray.util.state import list_actors
import logging
import httpx
from fastapi import HTTPException, WebSocket, WebSocketDisconnect

import asyncio
import websockets
from fastapi import WebSocketDisconnect

from app.models import Health, ActorInfo, BrowserList, BrowserInfo, BrowserStatus 
from app.lib import fetch_ws

logger = logging.getLogger(__name__)

@ray.remote(num_cpus=1)
class BrowserActor:
    """Actor to manage a single Chrome instance on a worker node"""
    
    def __init__(self, browser_id: str):
        """
        Initialize browser actor.
        
        Args:
            browser_id: Unique identifier for this browser instance
        """
        self.browser_id = browser_id
        self.pod_ip = ray.util.get_node_ip_address()
        
    async def get_info(self):
        """
        Get browser connection information.
        
        Returns:
            BrowserInfo: Browser details including ID, pod IP, WebSocket URL, and readiness status
        """
        ws_url = await fetch_ws(self.pod_ip)
        return BrowserInfo(
            browser_id=self.browser_id,
            pod_ip=self.pod_ip,
            websocket_url=f"/ws/browsers/{self.browser_id}{ws_url.split('9222')[-1]}" if ws_url else None,
            chrome_ready=bool(ws_url)
        )


class BrowserService:
    """Service to manage browser instances"""
    
    def __init__(self):
        self.browsers = {}
    

    async def health(self):
        try:
            ray_status = ray.is_initialized()
            active_browsers = len(self.browsers)
            return Health(status="healthy", ray_status=ray_status, active_browsers=active_browsers)
        
        except Exception as e:
            raise HTTPException(status_code=503, detail=f"Unhealthy: {e}")
    


    async def create_browser(self):
        browser_id = str(uuid.uuid4())
        actor = BrowserActor.remote(browser_id)
        
        self.browsers[browser_id] = actor
        
        return ActorInfo(
            browser_id=browser_id,
            proxy_url=f"/ws/browsers/{browser_id}/devtools/browser"
        )
  


    async def list_browsers(self):
        actors = list_actors(filters=[("class_name", "=", "BrowserActor")])

        browsers = [
            {"browser_id": actor.name, "state": actor.state}
            for actor in actors
        ]

        try:
            cluster = ray.cluster_resources()
            available = ray.available_resources()
            total_cpus = cluster.get("CPU", 0)
            available_cpus = available.get("CPU", 0)
        except Exception:
            total_cpus = available_cpus = None

        return BrowserList(total_cpus=total_cpus, available_cpus=available_cpus, browsers=browsers)

    
    async def get_browser(self, browser_id: str):
        actor = self.browsers.get(browser_id)
        if not actor:
            raise HTTPException(status_code=404, detail="Browser not found")
        return await actor.get_info.remote()


    async def delete_browser(self, browser_id: str):
        actor = self.browsers.pop(browser_id, None)
        if not actor:
            raise HTTPException(status_code=404, detail="Browser not found")
        try:
            ray.kill(actor)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to kill actor {e}")
        
        return BrowserStatus(browser_id=browser_id, status="closed")
        

    
    async def websocket_proxy(self, websocket: WebSocket, browser_id: str, path: str) -> None:
        await websocket.accept()

        actor = self.browsers.get(browser_id)
        if not actor:
            await websocket.close(code=1008, reason="Browser not found")
            return

        info = await actor.get_info.remote()
        if not info.chrome_ready:
            await websocket.close(code=1011, reason="Chrome not ready")
            return

        # Verify Chrome is reachable
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"http://{info.pod_ip}:9222/json/version", timeout=2)
                resp.raise_for_status()
        except Exception as exc:
            await websocket.close(code=1011, reason=f"Chrome unreachable: {exc}")
            return

        chrome_ws_url = f"ws://{info.pod_ip}:9222/{path}"

        async with websockets.connect(chrome_ws_url, timeout=5) as chrome_ws:
            async def client_to_chrome():
                try:
                    while True:
                        msg = await websocket.receive_text()
                        await chrome_ws.send(msg)
                except WebSocketDisconnect:
                    pass  # client hung up

            async def chrome_to_client():
                try:
                    async for msg in chrome_ws:
                        await websocket.send_text(msg)
                except websockets.exceptions.ConnectionClosed:
                    pass  # chrome died

            await asyncio.gather(client_to_chrome(), chrome_to_client())
        
