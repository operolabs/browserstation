
import argparse
import json
import time
from typing import Optional

import requests
from pydantic import BaseModel, HttpUrl

from crewai import Agent, Task, Crew
from crewai.tools import BaseTool
from playwright.sync_api import sync_playwright

API_URL = "http://localhost:8050"


class BrowserToolInput(BaseModel):
    url: HttpUrl
    screenshot_path: Optional[str] = None


class BrowserstationTool(BaseTool):
    name = "browserstation_tool"
    description = "Launches remote browser, navigates to a URL, retrieves title and optional screenshot"
    args_schema = BrowserToolInput

    def _run(self, url: str, screenshot_path: Optional[str] = None) -> str:
        browser_id = None
        result = {"ok": False}

        try:
            resp = requests.post(f"{API_URL}/browsers", timeout=30)
            resp.raise_for_status()
            browser_id = resp.json()["browser_id"]

            time.sleep(5)

            details = requests.get(
                f"{API_URL}/browsers/{browser_id}", timeout=30
            ).json()
            websocket_url = details["websocket_url"]

            if websocket_url.startswith("ws"):
                ws_url = websocket_url
            else:
                ws_url = f"ws://localhost:8050{websocket_url}"

            with sync_playwright() as p:
                browser = p.chromium.connect_over_cdp(ws_url)
                context = browser.new_context()
                page = context.new_page()

                page.goto(url)
                time.sleep(2)

                result.update(
                    {
                        "ok": True,
                        "title": page.title(),
                        "final_url": page.url,
                    }
                )

                if screenshot_path:
                    page.screenshot(path=screenshot_path)
                    result["screenshot_path"] = screenshot_path

                browser.close()

        except Exception as e:
            result["error"] = str(e)
        finally:
            if browser_id:
                try:
                    requests.delete(f"{API_URL}/browsers/{browser_id}", timeout=10)
                except Exception:
                    pass

        return json.dumps(result, indent=2)


def main(url: str, screenshot_path: Optional[str] = None) -> None:
    tool = BrowserstationTool()
    print("Invoking BrowserstationTool directly...")
    direct_result = tool._run(url=url, screenshot_path=screenshot_path)
    print("\nTool result:\n", direct_result)

    agent = Agent(
        role="Web Navigator",
        goal="Visit URLs and report results",
        tools=[tool],
        verbose=True,
    )

    task = Task(
        description=f"Visit {url} and return the title and URL",
        expected_output="JSON with title and URL",
        agent=agent,
        verbose=True,
    )

    crew = Crew(agents=[agent], tasks=[task], verbose=True)
    print("\nStarting agent with browserstation tool...")
    crew_result = crew.kickoff()
    print("\nAgent result:\n", crew_result)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Navigate to a URL in a remote browser and report the page title"
    )
    parser.add_argument("--url", required=True, help="Target URL to visit")
    parser.add_argument(
        "--screenshot",
        dest="screenshot_path",
        help="Optional path to save a PNG screenshot",
    )
    args = parser.parse_args()

    main(url=args.url, screenshot_path=args.screenshot_path)
