# lib.py
import httpx

async def fetch_ws(ip: str, timeout: float = 2.0):
    """Fetch browser-level WebSocket URL from Chrome"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"http://{ip}:9222/json/version", timeout=timeout)
        if response.status_code != 200:
            return None
        ws_url = response.json().get("webSocketDebuggerUrl", "")
        return ws_url.replace("localhost", ip)
    
    except Exception as e:
        return None