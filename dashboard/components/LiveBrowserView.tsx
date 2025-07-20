"use client"

import { useEffect, useRef, useState } from "react"
import useWebSocket, { ReadyState } from "react-use-websocket"
import { apiClient } from "@/lib/api"

interface LiveBrowserViewProps {
  browserId: string
  websocketUrl?: string
  className?: string
}

export function LiveBrowserView({ browserId, className = "" }: LiveBrowserViewProps) {
  const [wsUrl, setWsUrl] = useState<string | null>(null)
  const [noPages, setNoPages] = useState(false)
  const { sendJsonMessage, lastJsonMessage, readyState } = useWebSocket(wsUrl, {
    shouldReconnect: () => true,
    reconnectAttempts: 5,
    reconnectInterval: 3000,
  })

  const msgId = useRef(1)
  const sessionId = useRef<string | null>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const isInitialized = useRef(false)

  // Poll until Chrome is ready
  useEffect(() => {
    const checkBrowser = async () => {
      try {
        const info = await apiClient.getBrowser(browserId)
        if (info.chrome_ready && info.websocket_url) {
          const fullUrl = apiClient.getWebSocketUrl(browserId, info.websocket_url)
          setWsUrl(fullUrl)
          return true
        }
      } catch {
        // Silently retry
      }
      return false
    }
    
    const interval = setInterval(async () => {
      const ready = await checkBrowser()
      if (ready) {
        clearInterval(interval)
      }
    }, 1000)
    checkBrowser()
    
    return () => clearInterval(interval)
  }, [browserId])

  // Initialize when WebSocket connects and poll for pages
  useEffect(() => {
    if (readyState === ReadyState.OPEN && !isInitialized.current) {
      isInitialized.current = true
      sendJsonMessage({
        id: msgId.current++,
        method: "Target.getTargets"
      })
      
      // Poll for pages every 2 seconds if no pages
      const interval = setInterval(() => {
        if (noPages && readyState === ReadyState.OPEN) {
          sendJsonMessage({
            id: msgId.current++,
            method: "Target.getTargets"
          })
        }
      }, 2000)
      
      return () => clearInterval(interval)
    }
  }, [readyState, sendJsonMessage, noPages])

  // Handle messages
  useEffect(() => {
    if (!lastJsonMessage) return
    
    interface TargetInfo {
      targetId: string
      type: string
      title: string
      url: string
      attached: boolean
      browserContextId?: string
    }
    
    interface Message {
      id?: number
      method?: string
      result?: {
        targetInfos?: TargetInfo[]
        targetId?: string
        sessionId?: string
      }
      params?: {
        data?: string
        metadata?: {
          deviceWidth: number
          deviceHeight: number
        }
        sessionId?: string
      }
    }
    
    const msg = lastJsonMessage as Message
    
    // Handle getTargets response
    if (msg.id && msg.result?.targetInfos) {
      const pages = msg.result.targetInfos.filter((t) => t.type === "page")
      
      if (pages.length > 0) {
        // Attach to first page
        const page = pages[0]
        setNoPages(false)
        sendJsonMessage({
          id: msgId.current++,
          method: "Target.attachToTarget",
          params: {
            targetId: page.targetId,
            flatten: true
          }
        })
      } else {
        // No pages available
        setNoPages(true)
      }
      return
    }
    
    // Remove createTarget response handler since we don't create pages
    
    // Handle attachToTarget response
    if (msg.id && msg.result?.sessionId) {
      sessionId.current = msg.result.sessionId
      
      // Enable Page domain
      sendJsonMessage({
        id: msgId.current++,
        method: "Page.enable",
        sessionId: sessionId.current
      })
      
      // Start screencast
      sendJsonMessage({
        id: msgId.current++,
        method: "Page.startScreencast",
        params: {
          format: "jpeg",
          quality: 80,
          everyNthFrame: 1,
          maxWidth: 1600,
          maxHeight: 800
        },
        sessionId: sessionId.current
      })
      
      // Don't navigate - let the user control navigation
      return
    }
    
    // Handle screencast frames
    if (msg.method === "Page.screencastFrame" && msg.params) {
      const { data, metadata, sessionId: frameSessionId } = msg.params
      
      if (!canvasRef.current || !data || !metadata) return
      
      const ctx = canvasRef.current.getContext("2d")
      if (!ctx) return
      
      // Set canvas size on first frame
      if (canvasRef.current.width !== metadata.deviceWidth || 
          canvasRef.current.height !== metadata.deviceHeight) {
        canvasRef.current.width = metadata.deviceWidth
        canvasRef.current.height = metadata.deviceHeight
      }
      
      // Draw frame
      const img = new Image()
      img.onload = () => {
        ctx.drawImage(img, 0, 0)
      }
      img.src = `data:image/jpeg;base64,${data}`
      
      // Acknowledge frame
      sendJsonMessage({
        id: msgId.current++,
        method: "Page.screencastFrameAck",
        params: { sessionId: frameSessionId },
        sessionId: sessionId.current!
      })
    }
  }, [lastJsonMessage, sendJsonMessage])

  // Loading state
  if (!wsUrl || readyState === ReadyState.CONNECTING) {
    return (
      <div className={`relative ${className} bg-gray-100 flex items-center justify-center`}>
        <div className="animate-pulse text-gray-600">Connecting...</div>
      </div>
    )
  }

  // Show no pages message
  if (noPages) {
    return (
      <div className={`relative ${className} bg-gray-100 flex items-center justify-center`}>
        <div className="text-center">
          <div className="text-gray-600 font-medium">No pages available</div>
          <div className="text-gray-500 text-sm mt-1">Create a page using Playwright or Puppeteer</div>
        </div>
      </div>
    )
  }

  return (
    <div className={`relative overflow-hidden ${className}`}>
      <canvas 
        ref={canvasRef}
        className="w-full h-full"
        style={{ 
          objectFit: "contain",
          display: "block"
        }}
      />
    </div>
  )
}