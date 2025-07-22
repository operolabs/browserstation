#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "playwright>=1.40.0",
#     "requests>=2.31.0",
# ]
# ///

import asyncio
import random
import time
import requests
from playwright.async_api import async_playwright

API_URL = "http://localhost:8050"
NUM_BROWSERS = 5
MAX_CONCURRENT_BROWSERS = 5  # browserstation might have a limit
STAGGER_DELAY = 5  # seconds between starting each browser

# Different Wikipedia starting points for variety
WIKIPEDIA_TOPICS = [
    "https://en.wikipedia.org/wiki/Main_Page",
    "https://en.wikipedia.org/wiki/Computer_science",
    "https://en.wikipedia.org/wiki/History_of_the_Internet",
    "https://en.wikipedia.org/wiki/Artificial_intelligence",
    "https://en.wikipedia.org/wiki/Space_exploration",
    "https://en.wikipedia.org/wiki/Mathematics"
]

# Different sections of Wikipedia to explore
WIKIPEDIA_PORTALS = [
    "https://en.wikipedia.org/wiki/Portal:Technology",
    "https://en.wikipedia.org/wiki/Portal:Science",
    "https://en.wikipedia.org/wiki/Portal:History",
    "https://en.wikipedia.org/wiki/Portal:Geography",
    "https://en.wikipedia.org/wiki/Portal:Arts",
    "https://en.wikipedia.org/wiki/Portal:Biography"
]

async def scroll_slowly(page, duration=2):
    """Scroll down the page slowly over the specified duration"""
    start_time = time.time()
    while time.time() - start_time < duration:
        try:
            await page.evaluate("window.scrollBy(0, 100)")
            await asyncio.sleep(0.1)
        except Exception:
            # Page might have navigated, ignore scroll errors
            break

async def browse_wikipedia(page, browser_num, max_time=40):
    """Browse Wikipedia pages with content detection"""
    # Each browser starts at a different Wikipedia page
    start_url = WIKIPEDIA_TOPICS[(browser_num - 1) % len(WIKIPEDIA_TOPICS)]
    
    print(f"[Browser {browser_num}] Navigating to Wikipedia: {start_url.split('/')[-1]}...")
    try:
        await page.goto(start_url, timeout=15000)
        await page.wait_for_load_state("networkidle", timeout=5000)
        print(f"[Browser {browser_num}] Reached Wikipedia page")
    except Exception as e:
        print(f"[Browser {browser_num}] Error loading Wikipedia: {e}")
        return
    
    await asyncio.sleep(2)
    await scroll_slowly(page, 3)
    
    # If we're on the main page, try featured article
    if browser_num == 1:
        try:
            featured_article = page.locator("#mp-tfa a").first
            if await featured_article.count() > 0:
                article_text = await featured_article.text_content()
                print(f"[Browser {browser_num}] Clicking on featured article: {article_text[:50] if article_text else 'Unknown'}...")
                await featured_article.click()
                await page.wait_for_load_state("networkidle", timeout=10000)
                await asyncio.sleep(2)
                await scroll_slowly(page, 3)
        except Exception as e:
            print(f"[Browser {browser_num}] Could not click featured article: {e}")
    
    # Click on different types of links based on browser number
    try:
        # Different selectors for variety
        if browser_num % 3 == 0:
            # Look for links in the main content
            article_links = await page.locator("#mw-content-text p a[href*='/wiki/']").all()
        elif browser_num % 3 == 1:
            # Look for links in lists
            article_links = await page.locator("#mw-content-text li a[href*='/wiki/']").all()
        else:
            # Look for any content links
            article_links = await page.locator("#content a[href*='/wiki/']").filter(has_text=True).all()
        
        visible_links = []
        for link in article_links[:30]:  # Check more links for variety
            try:
                if await link.is_visible():
                    href = await link.get_attribute("href")
                    if href and "/wiki/" in href and ":" not in href.split("/wiki/")[1]:
                        visible_links.append(link)
            except:
                continue
        
        if visible_links:
            # Pick a different link for each browser
            link_index = (browser_num * 3) % len(visible_links)
            selected_link = visible_links[link_index]
            link_text = await selected_link.text_content()
            print(f"[Browser {browser_num}] Clicking on article link: {link_text}")
            await selected_link.click()
            await page.wait_for_load_state("networkidle", timeout=10000)
            await asyncio.sleep(2)
            await scroll_slowly(page, 3)
    except Exception as e:
        print(f"[Browser {browser_num}] Could not click article link: {e}")
    
    # Visit a portal page for variety
    try:
        portal_url = WIKIPEDIA_PORTALS[(browser_num - 1) % len(WIKIPEDIA_PORTALS)]
        print(f"[Browser {browser_num}] Visiting Wikipedia portal: {portal_url.split(':')[-1]}")
        await page.goto(portal_url, timeout=15000)
        await page.wait_for_load_state("networkidle", timeout=10000)
        await asyncio.sleep(2)
        await scroll_slowly(page, 2)
        
        # Click on a link in the portal
        portal_links = await page.locator("#mw-content-text a[href*='/wiki/']").all()
        visible_portal_links = []
        for link in portal_links[:20]:
            try:
                if await link.is_visible():
                    href = await link.get_attribute("href")
                    if href and "/wiki/" in href and "Portal:" not in href:
                        visible_portal_links.append(link)
            except:
                continue
        
        if visible_portal_links:
            # Different selection strategy per browser
            if browser_num % 2 == 0:
                selected_link = visible_portal_links[min(browser_num * 2, len(visible_portal_links) - 1)]
            else:
                selected_link = random.choice(visible_portal_links)
            
            link_text = await selected_link.text_content()
            print(f"[Browser {browser_num}] Clicking on portal link: {link_text}")
            await selected_link.click()
            await page.wait_for_load_state("networkidle", timeout=10000)
            await asyncio.sleep(2)
            await scroll_slowly(page, 3)
    except Exception as e:
        print(f"[Browser {browser_num}] Could not browse portal: {e}")

async def browse_hackernews(page, browser_num, max_time=40):
    """Browse Hacker News with content detection"""
    print(f"[Browser {browser_num}] Navigating to Hacker News...")
    
    # Different starting points on HN
    try:
        if browser_num % 4 == 0:
            await page.goto("https://news.ycombinator.com/newest", timeout=10000)
            print(f"[Browser {browser_num}] Browsing newest stories")
        elif browser_num % 4 == 1:
            await page.goto("https://news.ycombinator.com/best", timeout=10000)
            print(f"[Browser {browser_num}] Browsing best stories")
        elif browser_num % 4 == 2:
            await page.goto("https://news.ycombinator.com/ask", timeout=10000)
            print(f"[Browser {browser_num}] Browsing Ask HN")
        else:
            await page.goto("https://news.ycombinator.com", timeout=10000)
            print(f"[Browser {browser_num}] Browsing front page")
    except Exception as e:
        print(f"[Browser {browser_num}] Error loading HN: {e}")
        try:
            await page.goto("https://news.ycombinator.com", timeout=10000)
        except:
            return
    
    try:
        await page.wait_for_selector(".athing", timeout=8000)
        print(f"[Browser {browser_num}] Reached Hacker News")
    except Exception as e:
        print(f"[Browser {browser_num}] Error waiting for HN content: {e}")
        return
    
    await asyncio.sleep(2)
    await scroll_slowly(page, 3)
    
    # Get all story links
    try:
        stories = await page.locator(".athing .titleline > a").all()
        
        # Click on different stories for each browser
        if stories:
            # Each browser clicks on different stories
            story_indices = [
                (browser_num - 1) % len(stories),
                (browser_num * 2) % len(stories),
                (browser_num * 3 + 5) % len(stories)
            ]
            
            for i, story_index in enumerate(story_indices[:1]):  # First story
                if story_index < len(stories):
                    story = stories[story_index]
                    story_title = await story.text_content()
                    print(f"[Browser {browser_num}] Clicking on story #{story_index + 1}: {story_title}")
                    
                    href = await story.get_attribute("href")
                    if href and href.startswith("http"):
                        # External link - open in new tab
                        new_page = await page.context.new_page()
                        try:
                            await new_page.goto(href, timeout=8000)
                            await new_page.wait_for_load_state("domcontentloaded", timeout=3000)
                            await asyncio.sleep(3)
                            await scroll_slowly(new_page, 3)
                            print(f"[Browser {browser_num}] Browsed external article: {story_title}")
                        except Exception as e:
                            print(f"[Browser {browser_num}] Failed to load external article: {e}")
                        finally:
                            await new_page.close()
                    else:
                        await story.click()
                        await page.wait_for_load_state("networkidle")
                        await asyncio.sleep(2)
                        await scroll_slowly(page, 3)
                        await page.go_back()
                        await page.wait_for_selector(".athing", timeout=8000)
    except Exception as e:
        print(f"[Browser {browser_num}] Error browsing stories: {e}")
    
    # Browse comments on different stories
    try:
        await asyncio.sleep(2)
        comment_links = await page.locator(".subtext a:has-text('comment')").all()
        
        if comment_links:
            # Each browser reads different comments
            comment_index = ((browser_num - 1) * 3 + 1) % len(comment_links)
            if comment_index < len(comment_links):
                comment_link = comment_links[comment_index]
                comments_text = await comment_link.text_content()
                print(f"[Browser {browser_num}] Reading comments on story #{comment_index + 1}: {comments_text}")
                await comment_link.click()
                await page.wait_for_load_state("networkidle")
                await asyncio.sleep(2)
                await scroll_slowly(page, 3)
                
                # Try to expand some comment threads
                try:
                    toggle_links = await page.locator("a.togg").all()
                    if toggle_links and len(toggle_links) > browser_num:
                        await toggle_links[browser_num % len(toggle_links)].click()
                        await asyncio.sleep(1)
                except:
                    pass
    except Exception as e:
        print(f"[Browser {browser_num}] Error browsing comments: {e}")
    
    # Browse one more different article per browser
    try:
        await page.goto("https://news.ycombinator.com", timeout=10000)
        await page.wait_for_selector(".athing", timeout=8000)
        stories = await page.locator(".athing .titleline > a").all()
    except Exception as e:
        print(f"[Browser {browser_num}] Error returning to HN: {e}")
        return
    
    if stories:
        # Pick a story further down the list for variety
        final_index = (browser_num * 4 + 10) % len(stories)
        if final_index < len(stories):
            final_story = stories[final_index]
            try:
                story_title = await final_story.text_content()
                print(f"[Browser {browser_num}] Final story #{final_index + 1}: {story_title}")
                
                href = await final_story.get_attribute("href")
                if href and href.startswith("http"):
                    new_page = await page.context.new_page()
                    try:
                        await new_page.goto(href, timeout=8000)
                        await new_page.wait_for_load_state("domcontentloaded", timeout=3000)
                        await asyncio.sleep(3)
                        await scroll_slowly(new_page, 3)
                        print(f"[Browser {browser_num}] Browsed article: {story_title}")
                    except Exception as e:
                        print(f"[Browser {browser_num}] Failed to load article: {e}")
                    finally:
                        await new_page.close()
            except Exception as e:
                print(f"[Browser {browser_num}] Error with final story: {e}")

async def keep_browser_alive(page, duration):
    """Keep the browser alive by periodically evaluating JavaScript"""
    start = time.time()
    while time.time() - start < duration:
        try:
            await page.evaluate("() => { return document.title; }")
        except:
            # Page might be navigating, that's okay
            pass
        await asyncio.sleep(5)

async def browse_session(browser_num, start_delay):
    """Run a single browser session"""
    # Wait for staggered start
    await asyncio.sleep(start_delay)
    
    session_start_time = time.time()  # Track overall session time
    browser_id = None
    playwright = None
    browser = None
    keep_alive_task = None
    
    try:
        # Create a browser instance in browserstation
        print(f"[Browser {browser_num}] Creating browser instance...")
        resp = requests.post(f"{API_URL}/browsers", timeout=30)
        resp.raise_for_status()
        browser_id = resp.json()["browser_id"]
        print(f"[Browser {browser_num}] Created with ID: {browser_id}")
        
        # Wait for browser to be ready
        await asyncio.sleep(3)
        
        # Get browser details with retries
        max_retries = 3
        for retry in range(max_retries):
            try:
                details = requests.get(f"{API_URL}/browsers/{browser_id}", timeout=30).json()
                if "websocket_url" in details:
                    websocket_url = details["websocket_url"]
                    break
                else:
                    print(f"[Browser {browser_num}] Waiting for websocket URL... (attempt {retry + 1})")
                    await asyncio.sleep(2)
            except Exception as e:
                print(f"[Browser {browser_num}] Error getting browser details: {e}")
                await asyncio.sleep(2)
        else:
            raise Exception("Could not get websocket URL after retries")
        
        if websocket_url.startswith("ws"):
            ws_url = websocket_url
        else:
            ws_url = f"ws://localhost:8050{websocket_url}"
        
        print(f"[Browser {browser_num}] Connecting to: {ws_url}")
        
        # Connect to the browser via Playwright
        playwright = await async_playwright().start()
        browser = await playwright.chromium.connect_over_cdp(ws_url)
        context = browser.contexts[0]  # Use existing context
        page = context.pages[0] if context.pages else await context.new_page()
        
        # Start keep-alive task to prevent browser from being cleaned up
        keep_alive_task = asyncio.create_task(keep_browser_alive(page, 95))
        
        browsing_start_time = time.time()  # Track actual browsing time
        
        try:
            # Browse Wikipedia (approximately 35-40 seconds)
            # Set up timing for each section
            wiki_start = time.time()
            await browse_wikipedia(page, browser_num)
            wiki_elapsed = time.time() - wiki_start
            
            # Ensure we spend at least 40 seconds on Wikipedia section
            if wiki_elapsed < 40:
                wait_time = 40 - wiki_elapsed
                print(f"[Browser {browser_num}] Waiting {wait_time:.1f}s to complete Wikipedia section...")
                await asyncio.sleep(wait_time)
            
            # Browse Hacker News (approximately 45-50 seconds)
            hn_start = time.time()
            await browse_hackernews(page, browser_num)
            hn_elapsed = time.time() - hn_start
            
            # Ensure we spend at least 40 seconds on HN section
            if hn_elapsed < 40:
                wait_time = 40 - hn_elapsed
                print(f"[Browser {browser_num}] Waiting {wait_time:.1f}s to complete HN section...")
                await asyncio.sleep(wait_time)
            
        except Exception as e:
            print(f"[Browser {browser_num}] Error during browsing: {e}")
        
        # Ensure each browser runs for ~90 seconds of actual browsing
        browsing_elapsed = time.time() - browsing_start_time
        if browsing_elapsed < 90:
            wait_time = 90 - browsing_elapsed
            print(f"[Browser {browser_num}] Waiting {wait_time:.1f} more seconds...")
            await asyncio.sleep(wait_time)
        
        total_elapsed = time.time() - session_start_time
        print(f"[Browser {browser_num}] Total session time: {total_elapsed:.1f} seconds (browsing: 90.0s)")
        
        # Cancel keep-alive task
        if keep_alive_task:
            keep_alive_task.cancel()
        
        # NOW close the browser connection after we've waited the full time
        try:
            if browser:
                await browser.close()
        except:
            pass
        
        try:
            if playwright:
                await playwright.stop()
        except:
            pass
    
    except Exception as e:
        print(f"[Browser {browser_num}] Error in session: {e}")
    
    finally:
        # Cancel keep-alive task if it exists
        if keep_alive_task and not keep_alive_task.done():
            keep_alive_task.cancel()
        
        # Wait a bit before cleanup to ensure browser had full time
        await asyncio.sleep(2)
        
        # Clean up browser instance only
        if browser_id:
            try:
                print(f"[Browser {browser_num}] Cleaning up browser {browser_id}...")
                requests.delete(f"{API_URL}/browsers/{browser_id}", timeout=10)
            except Exception as e:
                print(f"[Browser {browser_num}] Error cleaning up: {e}")

async def main():
    """Run multiple browser sessions concurrently with staggered starts"""
    print(f"Starting {NUM_BROWSERS} browser sessions with {STAGGER_DELAY} second delays...")
    print("Each browser will visit different Wikipedia topics and Hacker News stories.\n")
    
    # Create tasks for all browser sessions
    tasks = []
    for i in range(NUM_BROWSERS):
        start_delay = i * STAGGER_DELAY
        task = asyncio.create_task(browse_session(i + 1, start_delay))
        tasks.append(task)
    
    # Wait for all tasks to complete
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    # Print any exceptions that occurred
    for i, result in enumerate(results):
        if isinstance(result, Exception):
            print(f"Browser {i + 1} failed with error: {result}")
    
    print("\nAll browser sessions completed!")

if __name__ == "__main__":
    asyncio.run(main())