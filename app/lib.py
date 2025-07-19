# lib.py
import httpx

async def fetch_ws(ip: str, timeout: float = 2.0):
    """Fetch WebSocket URL for the first page target instead of browser"""
    try:
        async with httpx.AsyncClient() as client:
            # Get list of all targets instead of version
            response = await client.get(f"http://{ip}:9222/json", timeout=timeout)
        if response.status_code != 200:
            return None
        
        targets = response.json()
        # Find the first page target
        page_target = next((t for t in targets if t.get("type") == "page"), None)
        
        if not page_target:
            # No page exists yet, create one
            async with httpx.AsyncClient() as client:
                # Create a new tab
                create_response = await client.put(
                    f"http://{ip}:9222/json/new?about:blank",
                    timeout=timeout
                )
                if create_response.status_code == 200:
                    # Get the newly created page's WebSocket URL
                    new_page = create_response.json()
                    ws_url = new_page.get("webSocketDebuggerUrl", "")
                    return ws_url.replace("localhost", ip)
            
            # Fallback to browser-level socket if creation failed
            response = await client.get(f"http://{ip}:9222/json/version", timeout=timeout)
            ws_url = response.json().get("webSocketDebuggerUrl", "")
            return ws_url.replace("localhost", ip)
        
        # Return the page WebSocket URL
        ws_url = page_target.get("webSocketDebuggerUrl", "")
        return ws_url.replace("localhost", ip)
    
    except Exception as e:
        return None