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
        pass
    

    async def health(self):
        try:
            ray_status = ray.is_initialized()
            
            # Get all browser actors and count by state
            alive_actors = list_actors(filters=[("class_name", "=", "BrowserActor"), ("state", "=", "ALIVE")])
            pending_actors = list_actors(filters=[("class_name", "=", "BrowserActor"), ("state", "=", "PENDING_CREATION")])
            dead_actors = list_actors(filters=[("class_name", "=", "BrowserActor"), ("state", "=", "DEAD")])
            
            browser_states = {
                "alive": len(alive_actors),
                "pending": len(pending_actors),
                "dead": len(dead_actors)
            }
            
            # Get resource information as dictionaries
            try:
                cluster = ray.cluster_resources()
                available = ray.available_resources()
            except Exception:
                cluster = {}
                available = {}
            
            return Health(
                status="healthy", 
                ray_status=ray_status, 
                browsers=browser_states,
                cluster=cluster,
                available=available
            )
        
        except Exception as e:
            raise HTTPException(status_code=503, detail=f"Unhealthy: {e}")
    


    async def create_browser(self):
        browser_id = str(uuid.uuid4())
        
        # Create the actor with a name
        actor = BrowserActor.options(name=browser_id, lifetime="detached").remote(browser_id)
        
        # Verify it was created by calling a method
        await actor.get_info.remote()
        
        return ActorInfo(
            browser_id=browser_id,
            proxy_url=f"/ws/browsers/{browser_id}/devtools/browser"
        )
  


    async def list_browsers(self):
        # Get alive and pending actors
        alive_actors = list_actors(filters=[("class_name", "=", "BrowserActor"), ("state", "=", "ALIVE")])
        pending_actors = list_actors(filters=[("class_name", "=", "BrowserActor"), ("state", "=", "PENDING_CREATION")])
        

        async def get_browser_info(actor):
            actor_handle = ray.get_actor(actor.name)
            info = await actor_handle.get_info.remote()
            return {"browser_id": actor.name, "state": "ALIVE", "websocket_url": info.websocket_url}
          
        
        alive_browsers = [await get_browser_info(actor) for actor in alive_actors]
        pending_browsers = [{"browser_id": actor.name, "state": "PENDING", "websocket_url": None} for actor in pending_actors]
        
        return BrowserList(browsers=alive_browsers + pending_browsers)

    
    async def get_browser(self, browser_id: str):
        try:
            actor = ray.get_actor(browser_id)
            return await actor.get_info.remote()
        except ValueError:
            raise HTTPException(status_code=404, detail="Browser not found")


    async def delete_browser(self, browser_id: str):
        try:
            actor = ray.get_actor(browser_id)
            ray.kill(actor)
            return BrowserStatus(browser_id=browser_id, status="closed")
        except ValueError:
            raise HTTPException(status_code=404, detail="Browser not found")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to kill actor {e}")
        

    
    async def websocket_proxy(self, websocket: WebSocket, browser_id: str, path: str) -> None:
        await websocket.accept()

        try:
            actor = ray.get_actor(browser_id)
        except ValueError:
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
        
