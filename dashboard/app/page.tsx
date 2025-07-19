"use client"

import { useState, useEffect } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Slider } from "@/components/ui/slider"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Label, PolarGrid, PolarRadiusAxis, RadialBar, RadialBarChart, Pie, PieChart } from "recharts"
import { ChartLegend, ChartLegendContent } from "@/components/ui/chart"
import { type ChartConfig, ChartContainer } from "@/components/ui/chart"
import { Copy, Trash2, Clock, AlertCircle } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

// Mock data based on the API response structure
const mockApiData = {
  status: "healthy",
  ray_status: true,
  browsers: {
    alive: 8,
    pending: 3,
    dead: 1,
  },
  cluster: {
    CPU: 48.0,
    memory: 206158430208.0,
    object_store_memory: 88353613209.0,
  },
  available: {
    CPU: 30.0,
    memory: 154618822656.0,
    object_store_memory: 66265209856.0,
  },
}

const agents = Array.from({ length: 12 }, (_, i) => ({
  id: String(i + 1),
  name: `Agent ${i + 1}`,
  uuid: `browser-${Math.random().toString(36).substring(2, 11)}-${Math.random().toString(36).substring(2, 6)}`,
  state: i < 8 ? "ALIVE" : i < 11 ? "PENDING" : "DEAD",
  websocket_url: `/ws/browsers/${Math.random().toString(36).substring(2, 10)}/devtools/browser/${Math.random().toString(36).substring(2, 10)}`,
}))

const chartConfig = {
  available: {
    label: "Available",
    color: "hsl(var(--chart-2))",
  },
} satisfies ChartConfig

const cpuChartConfig = {
  available: {
    label: "Available",
    color: "hsl(200, 70%, 50%)",  // Blue for CPU
  },
} satisfies ChartConfig

const memoryChartConfig = {
  available: {
    label: "Available",
    color: "hsl(280, 60%, 55%)",  // Purple for Memory
  },
} satisfies ChartConfig

const statusChartConfig = {
  agents: {
    label: "Agents",
  },
  alive: {
    label: "Active",
    color: "hsl(152, 60%, 50%)",  // Stronger green
  },
  pending: {
    label: "Pending",
    color: "hsl(38, 85%, 55%)",   // Stronger orange
  },
  dead: {
    label: "Dead",
    color: "hsl(0, 65%, 55%)",    // Stronger red
  },
} satisfies ChartConfig

export default function AgentMonitor() {
  const [columns, setColumns] = useState(3)
  const [filter, setFilter] = useState<"all" | "alive" | "pending">("all")
  const [isLoading, setIsLoading] = useState(true)

  const getStatusColor = (status: string) => {
    switch (status) {
      case "ALIVE":
        return "text-green-700 border-green-600 bg-green-50"
      case "PENDING":
        return "text-yellow-700 border-yellow-600 bg-yellow-50"
      case "DEAD":
        return "text-red-700 border-red-600 bg-red-50"
      default:
        return "text-gray-700 border-gray-600 bg-gray-50"
    }
  }

  useEffect(() => {
    // Show loading skeleton for 1 second
    const loadingTimer = setTimeout(() => {
      setIsLoading(false)
    }, 1000)

    return () => clearTimeout(loadingTimer)
  }, [])

  const handleCopy = (uuid: string) => {
    navigator.clipboard.writeText(uuid)
  }

  const handleDelete = (agentId: string) => {
    console.log(`Delete agent ${agentId}`)
  }

  const cpuPercentage = (mockApiData.available.CPU / mockApiData.cluster.CPU) * 100
  const cpuChartData = [{ name: "cpus", available: cpuPercentage, fill: "var(--color-available)" }]
  
  const memoryPercentage = (mockApiData.available.memory / mockApiData.cluster.memory) * 100
  const memoryChartData = [{ name: "memory", available: memoryPercentage, fill: "var(--color-available)" }]
  
  const filteredAgents = agents.filter(agent => {
    if (filter === "all") return true
    if (filter === "alive") return agent.state === "ALIVE"
    if (filter === "pending") return agent.state === "PENDING"
    return true
  })
  
  const statusChartData = [
    { status: "alive", agents: mockApiData.browsers.alive, fill: "var(--color-alive)" },
    { status: "pending", agents: mockApiData.browsers.pending, fill: "var(--color-pending)" },
    { status: "dead", agents: mockApiData.browsers.dead, fill: "var(--color-dead)" },
  ]

  return (
    <div className="px-12 py-12 pb-20 min-h-screen bg-white">
      <div className="mb-6">
        <div className="flex items-start justify-between">
          <div className="flex flex-col items-start">
            <div>
              {isLoading ? (
                <div className="h-12 w-64 bg-gray-200 rounded animate-pulse mb-1" />
              ) : (
                <div className="flex items-center gap-3 items-center">
                  <img src="/logo.png" alt="Browserstation Logo" className="h-12 w-12" />
                  <h1 className="text-5xl font-bold">Browserstation</h1>
                </div>
              )}
              <div className="flex items-center gap-1.5 mt-3">
                {isLoading ? (
                  <div className="h-3 w-32 bg-gray-200 rounded animate-pulse" />
                ) : (
                  <>
                    <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                    <span className="text-xs text-gray-600">All Systems Active</span>
                  </>
                )}
              </div>
            </div>
            <div className="flex items-center gap-4 mt-10">
              {isLoading ? (
                <>
                  <div className="h-4 w-12 bg-gray-200 rounded animate-pulse" />
                  <div className="h-6 w-40 bg-gray-200 rounded animate-pulse" />
                  <div className="h-6 w-8 bg-gray-200 rounded animate-pulse" />
                </>
              ) : (
                <>
                  <label className="text-sm font-medium text-gray-700">View</label>
                  <div className="flex items-center gap-3">
                    <Slider
                      value={[columns]}
                      onValueChange={(value) => setColumns(value[0])}
                      max={10}
                      min={1}
                      step={1}
                      className="w-64"
                    />
                    <div className="min-w-[2rem] text-center">
                      <span className="text-sm font-medium text-gray-900 bg-gray-100 px-2 py-1 rounded-md">
                        {columns}
                      </span>
                    </div>
                  </div>
                  <Tabs value={filter} onValueChange={(value) => setFilter(value as "all" | "alive" | "pending")}>
                    <TabsList>
                      <TabsTrigger value="all">All ({agents.length})</TabsTrigger>
                      <TabsTrigger value="alive">Active ({mockApiData.browsers.alive})</TabsTrigger>
                      <TabsTrigger value="pending">Pending ({mockApiData.browsers.pending})</TabsTrigger>
                    </TabsList>
                  </Tabs>
                </>
              )}
            </div>
          </div>

          <div className="flex justify-end gap-4">
            {isLoading ? (
              <>
                <div className="w-40 h-40 bg-gray-200 rounded-full animate-pulse" />
                <div className="w-40 h-40 bg-gray-200 rounded-full animate-pulse" />
                <div className="w-40 h-40 bg-gray-200 rounded-full animate-pulse" />
              </>
            ) : (
              <>
                <div className="flex flex-col items-center">
                  <ChartContainer
                    config={statusChartConfig}
                    className="aspect-square w-48 h-48"
                    title="Agent status distribution"
                  >
                    <PieChart>
                      <Pie 
                        data={statusChartData} 
                        dataKey="agents"
                        nameKey="status"
                        strokeWidth={2}
                        stroke="white"
                      />
                      <ChartLegend 
                        content={<ChartLegendContent nameKey="status" />}
                        className="mt-2"
                      />
                    </PieChart>
                  </ChartContainer>
                </div>
                <ChartContainer 
                  config={cpuChartConfig} 
                  className="aspect-square w-40 h-40"
                  title={`${mockApiData.available.CPU} out of ${mockApiData.cluster.CPU} CPUs available`}
                >
                  <RadialBarChart data={cpuChartData} endAngle={250} innerRadius={55} outerRadius={90}>
                    <PolarGrid
                      gridType="circle"
                      radialLines={false}
                      stroke="none"
                      className="first:fill-muted last:fill-background"
                      polarRadius={[70, 55]}
                    />
                    <RadialBar dataKey="available" background={{ fill: '#e3f2fd' }} fill="hsl(200, 70%, 50%)" />
                    <PolarRadiusAxis tick={false} tickLine={false} axisLine={false}>
                      <Label
                        content={({ viewBox }) => {
                          if (viewBox && "cx" in viewBox && "cy" in viewBox) {
                            return (
                              <text x={viewBox.cx} y={viewBox.cy} textAnchor="middle" dominantBaseline="middle">
                                <tspan x={viewBox.cx} y={viewBox.cy} className="fill-foreground text-2xl">
                                  {Math.round(mockApiData.available.CPU)}/{Math.round(mockApiData.cluster.CPU)}
                                </tspan>
                                <tspan
                                  x={viewBox.cx}
                                  y={(viewBox.cy || 0) + 24}
                                  className="fill-muted-foreground text-sm"
                                >
                                  CPUs
                                </tspan>
                              </text>
                            )
                          }
                        }}
                      />
                    </PolarRadiusAxis>
                  </RadialBarChart>
                </ChartContainer>
                <ChartContainer 
                  config={memoryChartConfig} 
                  className="aspect-square w-40 h-40"
                  title={`${(mockApiData.available.memory / 1e9).toFixed(1)} out of ${(mockApiData.cluster.memory / 1e9).toFixed(1)} GB memory available`}
                >
                  <RadialBarChart data={memoryChartData} endAngle={250} innerRadius={55} outerRadius={90}>
                    <PolarGrid
                      gridType="circle"
                      radialLines={false}
                      stroke="none"
                      className="first:fill-muted last:fill-background"
                      polarRadius={[70, 55]}
                    />
                    <RadialBar dataKey="available" background={{ fill: '#f3e5f5' }} fill="hsl(280, 60%, 55%)" />
                    <PolarRadiusAxis tick={false} tickLine={false} axisLine={false}>
                      <Label
                        content={({ viewBox }) => {
                          if (viewBox && "cx" in viewBox && "cy" in viewBox) {
                            return (
                              <text x={viewBox.cx} y={viewBox.cy} textAnchor="middle" dominantBaseline="middle">
                                <tspan x={viewBox.cx} y={viewBox.cy} className="fill-foreground text-xl">
                                  {Math.round(mockApiData.available.memory / 1e9)}/{Math.round(mockApiData.cluster.memory / 1e9)}
                                </tspan>
                                <tspan
                                  x={viewBox.cx}
                                  y={(viewBox.cy || 0) + 20}
                                  className="fill-muted-foreground text-xs"
                                >
                                  GB RAM
                                </tspan>
                              </text>
                            )
                          }
                        }}
                      />
                    </PolarRadiusAxis>
                  </RadialBarChart>
                </ChartContainer>
              </>
            )}
          </div>
        </div>
      </div>

      <div className="grid gap-4" style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}>
        {filteredAgents.map((agent) => (
          <div key={agent.id} className="h-fit overflow-hidden rounded bg-white border border-gray-200">
              {isLoading ? (
                <div className="w-full aspect-video bg-gray-200 rounded animate-pulse" />
              ) : (
                <>
                  {/* Browser Header Bar */}
                  <div className="bg-gray-100 px-3 py-2 flex items-center justify-between">
                    <div className="flex items-center gap-2 flex-1 min-w-0">
                      {agent.state === "PENDING" && <Clock className="h-3 w-3 text-yellow-600" />}
                      {agent.state === "DEAD" && <AlertCircle className="h-3 w-3 text-red-600" />}
                      <Badge variant="outline" className={`text-xs ${getStatusColor(agent.state)}`}>
                        {agent.state}
                      </Badge>
                      <span className="text-gray-700 text-xs font-mono truncate">{agent.uuid}</span>
                    </div>
                    <div className="flex items-center gap-2 flex-shrink-0">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleCopy(agent.uuid)}
                        className="p-1 h-auto hover:bg-gray-200"
                        title="Copy UUID"
                      >
                        <Copy className="h-3 w-3 text-gray-600" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleDelete(agent.id)}
                        className="p-1 h-auto hover:bg-red-100"
                        title="Delete Browser"
                      >
                        <Trash2 className="h-3 w-3 text-gray-600" />
                      </Button>
                    </div>
                  </div>
                  {/* Browser View */}
                  <div className="relative">
                    <img
                      src={`/placeholder.svg?height=1080&width=1920&text=Agent ${agent.id}`}
                      alt={`Agent ${agent.id} Browser View`}
                      className="w-full aspect-video object-cover"
                    />
                    {agent.state !== "ALIVE" && (
                      <div className="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center">
                        <div className="text-white text-center">
                          <div className="text-lg font-semibold">{agent.state}</div>
                          {agent.state === "PENDING" && <div className="text-sm opacity-75">Initializing...</div>}
                        </div>
                      </div>
                    )}
                  </div>
                </>
              )}
          </div>
        ))}
      </div>
    </div>
  )
}
