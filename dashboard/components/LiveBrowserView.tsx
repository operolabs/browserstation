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
    let interval: NodeJS.Timeout
    
    const checkBrowser = async () => {
      try {
        const info = await apiClient.getBrowser(browserId)
        if (info.chrome_ready && info.websocket_url) {
          const fullUrl = apiClient.getWebSocketUrl(browserId, info.websocket_url)
          setWsUrl(fullUrl)
          clearInterval(interval)
        }
      } catch (error) {
        // Silently retry
      }
    }
    
    interval = setInterval(checkBrowser, 1000)
    checkBrowser()
    
    return () => clearInterval(interval)
  }, [browserId])

  // Initialize when WebSocket connects
  useEffect(() => {
    if (readyState === ReadyState.OPEN && !isInitialized.current) {
      isInitialized.current = true
      sendJsonMessage({
        id: msgId.current++,
        method: "Target.getTargets"
      })
    }
  }, [readyState, sendJsonMessage])

  // Handle messages
  useEffect(() => {
    if (!lastJsonMessage) return
    
    const msg = lastJsonMessage as any
    
    // Handle getTargets response
    if (msg.id && msg.result?.targetInfos) {
      const pages = msg.result.targetInfos.filter((t: any) => t.type === "page")
      
      if (pages.length > 0) {
        // Attach to first page
        const page = pages[0]
        sendJsonMessage({
          id: msgId.current++,
          method: "Target.attachToTarget",
          params: {
            targetId: page.targetId,
            flatten: true
          }
        })
      } else {
        // Create new page
        sendJsonMessage({
          id: msgId.current++,
          method: "Target.createTarget",
          params: { url: "https://example.com" }
        })
      }
      return
    }
    
    // Handle createTarget response
    if (msg.id && msg.result?.targetId) {
      sendJsonMessage({
        id: msgId.current++,
        method: "Target.attachToTarget",
        params: {
          targetId: msg.result.targetId,
          flatten: true
        }
      })
      return
    }
    
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
          maxWidth: 800,
          maxHeight: 600
        },
        sessionId: sessionId.current
      })
      
      // Navigate to ensure content
      sendJsonMessage({
        id: msgId.current++,
        method: "Page.navigate",
        params: { url: "https://example.com" },
        sessionId: sessionId.current
      })
      return
    }
    
    // Handle screencast frames
    if (msg.method === "Page.screencastFrame") {
      const { data, metadata, sessionId: frameSessionId } = msg.params
      
      if (!canvasRef.current) return
      
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