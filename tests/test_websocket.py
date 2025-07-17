#!/usr/bin/env python3
"""
Example script showing how to use BrowserStation with Playwright
"""

from playwright.sync_api import sync_playwright
import requests
import time
import os
import sys

# BrowserStation API endpoint
API_URL = "http://localhost:8050"

def main():
    # Check for API key
    api_key = os.environ.get("BROWSERSTATION_API_KEY", "")
    headers = {}
    
    # Try a health check first to see if API key is required
    response = requests.get(f"{API_URL}/")
    if response.status_code == 200:
        # API is accessible, now check if endpoints require auth
        test_response = requests.post(f"{API_URL}/browsers")
        if test_response.status_code == 401:
            if not api_key:
                print("Error: This BrowserStation instance requires an API key")
                print("Please set it with: export BROWSERSTATION_API_KEY='your-secret-key'")
                sys.exit(1)
            headers = {"X-API-Key": api_key}
    elif response.status_code != 200:
        print(f"Error: Cannot connect to BrowserStation at {API_URL}")
        print("Make sure the service is running and port-forwarding is active")
        sys.exit(1)
    # Step 1: Create a browser
    print("Creating browser...")
    response = requests.post(f"{API_URL}/browsers", headers=headers)
    if response.status_code == 401:
        print("Error: Invalid API key")
        sys.exit(1)
    browser_data = response.json()
    browser_id = browser_data["browser_id"]
    print(f"Browser created: {browser_id}")
    
    # Step 2: Get browser details
    response = requests.get(f"{API_URL}/browsers/{browser_id}", headers=headers)
    browser_info = response.json()
    
    # Step 3: Wait for Chrome to be ready
    print("Waiting for Chrome to be ready...")
    for _ in range(10):
        response = requests.get(f"{API_URL}/browsers/{browser_id}", headers=headers)
        if response.json().get("chrome_ready"):
            break
        time.sleep(1)
    
    # Step 4: Connect with Playwright using the complete URL
    with sync_playwright() as p:
        ws_path = browser_info["websocket_url"]
        ws_url = f"ws://localhost:8050{ws_path}"
        print(f"Connecting to: {ws_url}")
        
        browser = p.chromium.connect_over_cdp(ws_url)
        
        page = browser.new_page()
        
        # Navigate to a site
        print("\nNavigating to example.com...")
        page.goto("https://example.com")
        
        # Get page title
        print(f"Page title: {page.title()}")
        
        # Take a screenshot
        page.screenshot(path="example.png")
        print("Screenshot saved as example.png")
        
        # Close browser
        browser.close()
    
    # Step 5: Clean up
    print("\nCleaning up...")
    requests.delete(f"{API_URL}/browsers/{browser_id}", headers=headers)
    print("Browser deleted")

if __name__ == "__main__":
    main()