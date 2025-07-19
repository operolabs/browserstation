"use client"

import { useState, useEffect } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Slider } from "@/components/ui/slider"
import { Label, PolarGrid, PolarRadiusAxis, RadialBar, RadialBarChart } from "recharts"
import { type ChartConfig, ChartContainer } from "@/components/ui/chart"
import { Copy, Trash2 } from "lucide-react"

const agents = Array.from({ length: 12 }, (_, i) => ({
  id: String(i + 1),
  name: `Agent ${i + 1}`,
  uuid: `browser-${Math.random().toString(36).substr(2, 9)}-${Math.random().toString(36).substr(2, 4)}`,
}))

const cpuData = {
  total_cpus: 64,
  available_cpus: 42,
}

const chartConfig = {
  available: {
    label: "Available CPUs",
    color: "hsl(var(--chart-2))",
  },
} satisfies ChartConfig

export default function AgentMonitor() {
  const [columns, setColumns] = useState(3)
  const [isLoading, setIsLoading] = useState(true)

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

  const percentage = (cpuData.available_cpus / cpuData.total_cpus) * 100
  const chartData = [{ name: "cpus", available: percentage, fill: "var(--color-available)" }]

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
                </>
              )}
            </div>
          </div>

          <div className="flex justify-end">
            {isLoading ? (
              <div className="w-40 h-40 bg-gray-200 rounded-full animate-pulse" />
            ) : (
              <ChartContainer 
                config={chartConfig} 
                className="aspect-square w-40 h-40"
                title={`${cpuData.available_cpus} out of ${cpuData.total_cpus} CPUs available`}
              >
                <RadialBarChart data={chartData} endAngle={250} innerRadius={55} outerRadius={90}>
                  <PolarGrid
                    gridType="circle"
                    radialLines={false}
                    stroke="none"
                    className="first:fill-muted last:fill-background"
                    polarRadius={[70, 55]}
                  />
                  <RadialBar dataKey="available" background={{ fill: '#000000' }} fill="hsl(var(--chart-2))" />
                  <PolarRadiusAxis tick={false} tickLine={false} axisLine={false}>
                    <Label
                      content={({ viewBox }) => {
                        if (viewBox && "cx" in viewBox && "cy" in viewBox) {
                          return (
                            <text x={viewBox.cx} y={viewBox.cy} textAnchor="middle" dominantBaseline="middle">
                              <tspan x={viewBox.cx} y={viewBox.cy} className="fill-foreground text-2xl">
                                {cpuData.available_cpus}/{cpuData.total_cpus}
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
            )}
          </div>
        </div>
      </div>

      <div className="grid gap-4" style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}>
        {agents.map((agent) => (
          <div key={agent.id} className="h-fit overflow-hidden rounded bg-white border border-gray-200">
              {isLoading ? (
                <div className="w-full aspect-video bg-gray-200 rounded animate-pulse" />
              ) : (
                <>
                  {/* Browser Header Bar */}
                  <div className="bg-gray-100 px-3 py-2 flex items-center justify-between">
                    <span className="text-gray-700 text-xs font-mono truncate mr-2">{agent.uuid}</span>
                    <div className="flex items-center gap-2 flex-shrink-0">
                      <button
                        onClick={() => handleCopy(agent.uuid)}
                        className="p-1 hover:bg-gray-200 rounded transition-colors"
                        title="Copy UUID"
                      >
                        <Copy className="h-3 w-3 text-gray-600 cursor-pointer" />
                      </button>
                      <button
                        onClick={() => handleDelete(agent.id)}
                        className="p-1 hover:bg-red-100 rounded transition-colors"
                        title="Delete Browser"
                      >
                        <Trash2 className="h-3 w-3 text-gray-600 cursor-pointer" />
                      </button>
                    </div>
                  </div>
                  {/* Browser View */}
                  <img
                    src={`/placeholder.svg?height=1080&width=1920&text=Agent ${agent.id}`}
                    alt={`Agent ${agent.id} Browser View`}
                    className="w-full aspect-video object-cover"
                  />
                </>
              )}
          </div>
        ))}
      </div>
    </div>
  )
}
