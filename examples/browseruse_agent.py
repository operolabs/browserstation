import asyncio
import time
import requests

from browser_use import BrowserSession, Agent
from browser_use.llm import ChatOpenAI

API_URL = "http://localhost:8050"


async def main() -> None:
    browser_id = None

    try:
        resp = requests.post(f"{API_URL}/browsers", timeout=30)
        resp.raise_for_status()
        browser_id = resp.json()["browser_id"]

        time.sleep(5)

        details = requests.get(f"{API_URL}/browsers/{browser_id}", timeout=30).json()
        websocket_url = details["websocket_url"]

        if websocket_url.startswith("ws"):
            ws_url = websocket_url
        else:
            ws_url = f"ws://localhost:8050{websocket_url}"

        session = BrowserSession(wss_url=ws_url)

        agent = Agent(
            task="Find the top three AI breakthroughs announced in the last week and summarize their security implications",
            llm=ChatOpenAI(model="gpt-4o"),
            browser_session=session,
            use_vision=False,
            save_conversation_path="logs/ai_news",
            extend_system_message=(
                "When summarizing, focus on potential privacy or security risks "
                "and keep each summary under 150 words"
            ),
        )

        print("Starting agent with remote browser session...")
        history = await agent.run()
        print("\nAgent result:\n", history.final_result())

    except Exception as e:
        print(f"\nError: {e}")
    finally:
        if browser_id:
            try:
                await session.browser.close()
            except Exception:
                pass
            try:
                requests.delete(f"{API_URL}/browsers/{browser_id}", timeout=10)
            except Exception:
                pass


if __name__ == "__main__":
    asyncio.run(main())
