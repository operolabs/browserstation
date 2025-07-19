// API client for BrowserStation backend

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8050'
const API_KEY = process.env.NEXT_PUBLIC_API_KEY || ''

// Debug logging
console.log('API URL:', API_URL)
console.log('API Key configured:', !!API_KEY)

// Types matching the FastAPI models
export interface BrowserInfo {
  id: string
  browser_id?: string  // API returns this field
  state: 'ALIVE' | 'PENDING' | 'DEAD'
  websocket_url: string
  chrome_ready?: boolean
  pod_ip?: string
}

export interface CreateBrowserResponse {
  browser_id: string
  proxy_url: string
}

export interface ClusterStatus {
  status: string
  ray_status: boolean
  browsers: {
    alive: number
    pending: number
    dead: number
  }
  cluster: {
    CPU: number
    memory: number
    object_store_memory: number
    [key: string]: number
  }
  available: {
    CPU: number
    memory: number
    object_store_memory: number
    [key: string]: number
  }
}

class APIClient {
  private headers: HeadersInit

  constructor() {
    this.headers = {
      'Content-Type': 'application/json',
    }
    if (API_KEY) {
      this.headers['X-API-Key'] = API_KEY
    }
  }

  async getStatus(): Promise<ClusterStatus> {
    const response = await fetch(`${API_URL}/`, {
      headers: this.headers,
    })
    if (!response.ok) throw new Error('Failed to fetch status')
    return response.json()
  }

  async listBrowsers(): Promise<BrowserInfo[]> {
    const response = await fetch(`${API_URL}/browsers`, {
      headers: this.headers,
    })
    if (!response.ok) throw new Error('Failed to list browsers')
    const data = await response.json()
    // Map browser_id to id for consistency
    return data.browsers.map((browser: any) => ({
      id: browser.browser_id,
      browser_id: browser.browser_id,
      state: browser.state,
      websocket_url: browser.websocket_url
    }))
  }

  async createBrowser(): Promise<CreateBrowserResponse> {
    const response = await fetch(`${API_URL}/browsers`, {
      method: 'POST',
      headers: this.headers,
    })
    if (!response.ok) throw new Error('Failed to create browser')
    return response.json()
  }

  async getBrowser(id: string): Promise<BrowserInfo> {
    const response = await fetch(`${API_URL}/browsers/${id}`, {
      headers: this.headers,
    })
    if (!response.ok) throw new Error('Failed to get browser')
    return response.json()
  }

  async deleteBrowser(id: string): Promise<{ message: string }> {
    const response = await fetch(`${API_URL}/browsers/${id}`, {
      method: 'DELETE',
      headers: this.headers,
    })
    if (!response.ok) throw new Error('Failed to delete browser')
    return response.json()
  }

  getWebSocketUrl(browserId: string, websocketPath?: string): string {
    // If we have the full websocket path from the API, use it
    if (websocketPath) {
      const wsProtocol = API_URL.startsWith('https') ? 'wss' : 'ws'
      const baseUrl = API_URL.replace(/^https?/, wsProtocol)
      return `${baseUrl}${websocketPath}`
    }
    // Otherwise construct a basic URL
    const wsProtocol = API_URL.startsWith('https') ? 'wss' : 'ws'
    const baseUrl = API_URL.replace(/^https?/, wsProtocol)
    return `${baseUrl}/ws/browsers/${browserId}/devtools/browser`
  }
}

export const apiClient = new APIClient()