"use client"

import { useState, useEffect } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Slider } from "@/components/ui/slider"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Label, PolarGrid, PolarRadiusAxis, RadialBar, RadialBarChart, Pie, PieChart } from "recharts"
import { ChartLegend, ChartLegendContent } from "@/components/ui/chart"
import { type ChartConfig, ChartContainer } from "@/components/ui/chart"
import { Copy, Trash2, Clock, AlertCircle, Plus, RefreshCw } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { apiClient, type BrowserInfo, type ClusterStatus } from "@/lib/api"
import { LiveBrowserView } from "@/components/LiveBrowserView"


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
} satisfies ChartConfig

export default function AgentMonitor() {
  const [columns, setColumns] = useState(3)
  const [filter, setFilter] = useState<"all" | "alive" | "pending">("all")
  const [isLoading, setIsLoading] = useState(true)
  const [agents, setAgents] = useState<BrowserInfo[]>([])
  const [clusterStatus, setClusterStatus] = useState<ClusterStatus | null>(null)
  const [isCreating, setIsCreating] = useState(false)

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

  // Fetch data from API
  const fetchData = async () => {
    try {
      const [statusData, browsersData] = await Promise.all([
        apiClient.getStatus(),
        apiClient.listBrowsers()
      ])
      setClusterStatus(statusData)
      setAgents(browsersData)
      setIsLoading(false)
    } catch (error) {
      console.error('Failed to fetch data:', error)
      setIsLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
    // Refresh data every 5 seconds
    const interval = setInterval(fetchData, 5000)
    return () => clearInterval(interval)
  }, [])

  const handleCopy = (id: string) => {
    navigator.clipboard.writeText(id)
  }

  const handleDelete = async (agentId: string) => {
    try {
      await apiClient.deleteBrowser(agentId)
      await fetchData()
    } catch (error) {
      console.error('Failed to delete browser:', error)
    }
  }

  const handleCreateBrowser = async () => {
    setIsCreating(true)
    try {
      await apiClient.createBrowser()
      await fetchData()
    } catch (error) {
      console.error('Failed to create browser:', error)
    } finally {
      setIsCreating(false)
    }
  }

  const cpuPercentage = clusterStatus ? (clusterStatus.available.CPU / clusterStatus.cluster.CPU) * 100 : 0
  const cpuChartData = [{ name: "cpus", available: cpuPercentage, fill: "var(--color-available)" }]
  
  const memoryPercentage = clusterStatus ? (clusterStatus.available.memory / clusterStatus.cluster.memory) * 100 : 0
  const memoryChartData = [{ name: "memory", available: memoryPercentage, fill: "var(--color-available)" }]
  
  const filteredAgents = agents.filter(agent => {
    if (filter === "all") return true
    if (filter === "alive") return agent.state === "ALIVE"
    if (filter === "pending") return agent.state === "PENDING"
    return true
  })
  
  const statusChartData = [
    { status: "alive", agents: clusterStatus?.browsers.alive || 0, fill: "var(--color-alive)" },
    { status: "pending", agents: clusterStatus?.browsers.pending || 0, fill: "var(--color-pending)" },
    { status: "dead", agents: clusterStatus?.browsers.dead || 0, fill: "var(--color-dead)" },
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
                    <span className="text-xs text-gray-600">{clusterStatus?.status === "healthy" ? "All Systems Active" : "System Issues"}</span>
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
                      <TabsTrigger value="alive">Active ({clusterStatus?.browsers.alive || 0})</TabsTrigger>
                      <TabsTrigger value="pending">Pending ({clusterStatus?.browsers.pending || 0})</TabsTrigger>
                    </TabsList>
                  </Tabs>
                  <div className="flex gap-2 ml-4">
                    <Button
                      onClick={handleCreateBrowser}
                      disabled={isCreating}
                      size="sm"
                      className="gap-2"
                    >
                      {isCreating ? (
                        <RefreshCw className="h-4 w-4 animate-spin" />
                      ) : (
                        <Plus className="h-4 w-4" />
                      )}
                      Create Browser
                    </Button>
                    <Button
                      onClick={fetchData}
                      variant="outline"
                      size="sm"
                    >
                      <RefreshCw className="h-4 w-4" />
                    </Button>
                  </div>
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
                  title={`${clusterStatus?.available.CPU || 0} out of ${clusterStatus?.cluster.CPU || 0} CPUs available`}
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
                                  {Math.round(clusterStatus?.available.CPU || 0)}/{Math.round(clusterStatus?.cluster.CPU || 0)}
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
                  title={`${((clusterStatus?.available.memory || 0) / 1e9).toFixed(1)} out of ${((clusterStatus?.cluster.memory || 0) / 1e9).toFixed(1)} GB memory available`}
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
                                  {Math.round((clusterStatus?.available.memory || 0) / 1e9)}/{Math.round((clusterStatus?.cluster.memory || 0) / 1e9)}
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
                      <span className="text-gray-700 text-xs font-mono truncate">{agent.id}</span>
                    </div>
                    <div className="flex items-center gap-2 flex-shrink-0">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleCopy(agent.id)}
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
                  {agent.state === "ALIVE" ? (
                    <LiveBrowserView 
                      browserId={agent.id}
                      websocketUrl={agent.websocket_url}
                      className="w-full aspect-video"
                    />
                  ) : (
                    <div className="relative">
                      <div className="w-full aspect-video bg-gray-200 flex items-center justify-center">
                        <div className="text-center">
                          <div className="text-lg font-semibold text-gray-600">{agent.state}</div>
                          {agent.state === "PENDING" && <div className="text-sm text-gray-500">Initializing browser...</div>}
                          {agent.state === "DEAD" && <div className="text-sm text-gray-500">Browser terminated</div>}
                        </div>
                      </div>
                    </div>
                  )}
                </>
              )}
          </div>
        ))}
      </div>
    </div>
  )
}
