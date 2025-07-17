import json
import os
import time
import tempfile
import requests
from playwright.sync_api import sync_playwright
from pydantic import BaseModel, HttpUrl

from langchain_openai import ChatOpenAI
from langchain_core.tools import tool
from langchain_core.messages import HumanMessage
from langgraph.prebuilt import create_react_agent

API_URL = "http://localhost:8050"


class BrowserInput(BaseModel):
    url: HttpUrl
    screenshot: bool = False
    html_chars: int = 0


@tool("browserstation_tool", args_schema=BrowserInput)
def browserstation_tool(
    url: HttpUrl, screenshot: bool = False, html_chars: int = 0
) -> str:
    browser_id = None
    result = {"ok": False}

    try:
        resp = requests.post(f"{API_URL}/browsers", timeout=30)
        resp.raise_for_status()
        browser_id = resp.json()["browser_id"]

        time.sleep(5)

        details = requests.get(f"{API_URL}/browsers/{browser_id}", timeout=30).json()
        ws_url = details["websocket_url"]
        if not ws_url.startswith(("ws://", "wss://")):
            ws_url = f"ws://localhost:8050{ws_url}"

        with sync_playwright() as p:
            remote_browser = p.chromium.connect_over_cdp(ws_url)
            context = remote_browser.new_context()
            page = context.new_page()
            page.goto(str(url))
            page.wait_for_load_state("load")

            result["ok"] = True
            result["title"] = page.title()
            result["final_url"] = page.url

            if screenshot:
                fd, path = tempfile.mkstemp(suffix=".png")
                os.close(fd)
                page.screenshot(path=path)
                result["screenshot_path"] = path

            if html_chars:
                result["html_snippet"] = page.content()[:html_chars]

            context.close()
            remote_browser.close()

    except Exception as e:
        result["error"] = repr(e)
    finally:
        if browser_id:
            try:
                requests.delete(f"{API_URL}/browsers/{browser_id}", timeout=10)
            except Exception:
                pass

    return json.dumps(result, indent=2)


def run_agent(task: str, model_name: str = "gpt-4o-mini") -> None:
    model = ChatOpenAI(model=model_name, temperature=0)
    agent = create_react_agent(model, tools=[browserstation_tool])
    config = {"configurable": {"thread_id": "demo"}}

    print("Agent response:\n")
    for event in agent.stream(
        {"messages": [HumanMessage(content=task)]}, config=config
    ):
        if isinstance(event, dict):
            msgs = event.get("messages") or []
            for m in msgs:
                print(f"[{m.__class__.__name__}] {getattr(m, 'content', '')}")
        else:
            print(event)


if __name__ == "__main__":
    run_agent("Visit https://example.com and tell me the title and take a screenshot")
