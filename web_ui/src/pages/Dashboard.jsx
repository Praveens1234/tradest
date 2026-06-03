import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import MetricCard from '../components/MetricCard'
import { listEAs } from '../api/ea'
import { getHistory } from '../api/backtest'
import api from '../api/client'

export default function Dashboard() {
  const [eas, setEAs] = useState([])
  const [runs, setRuns] = useState([])
  const [health, setHealth] = useState(null)
  const [loading, setLoading] = useState(true)
  const nav = useNavigate()

  useEffect(() => {
    Promise.all([
      listEAs().then((r) => setEAs(r.data)),
      getHistory(0, 10).then((r) => setRuns(r.data)),
      api.get('/health').then((r) => setHealth(r.data)),
    ]).finally(() => setLoading(false))
  }, [])

  const completed = runs.filter((r) => r.status === 'done').length
  const failed = runs.filter((r) => r.status === 'failed').length

  return (
    <div className="p-6 space-y-6">
      <h1 className="page-header">Dashboard</h1>

      {health && health.status === 'degraded' && (
        <div className="bg-yellow-950/40 border border-yellow-800/50 rounded-xl px-4 py-3 text-sm text-yellow-300">
          ⚠ MT5 paths not fully configured. Compile and backtest features are disabled.
          <button onClick={() => nav('/settings')} className="ml-2 underline hover:text-yellow-100">
            Go to Settings
          </button>
        </div>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricCard label="EAs Registered" value={eas.length} />
        <MetricCard label="Total Backtests" value={runs.length} />
        <MetricCard label="Completed" value={completed} positive={completed > 0} />
        <MetricCard label="Failed" value={failed} positive={failed === 0} />
      </div>

      {health && (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          <MetricCard label="CPU Usage" value={health.cpu_percent?.toFixed(1)} unit="%" />
          <MetricCard label="RAM Usage" value={health.memory_mb?.toFixed(0)} unit="MB" />
          <MetricCard
            label="Platform Status"
            value={health.status === 'ok' ? 'OK' : 'Degraded'}
            positive={health.status === 'ok'}
          />
        </div>
      )}

      <div>
        <h2 className="text-lg font-semibold mb-3">Recent Backtests</h2>
        {runs.length === 0 ? (
          <div className="card text-gray-500 text-sm">
            No backtests yet.{' '}
            <button onClick={() => nav('/backtest/setup')} className="text-brand-400 hover:underline">
              Run your first backtest →
            </button>
          </div>
        ) : (
          <div className="space-y-2">
            {runs.slice(0, 5).map((r) => (
              <div
                key={r.run_id}
                onClick={() => nav('/history')}
                className="card flex items-center justify-between cursor-pointer hover:border-gray-600 transition-colors"
              >
                <div className="flex items-center gap-4 text-sm">
                  <span className="font-medium">Run #{r.run_id}</span>
                  <span className="text-gray-500">EA #{r.ea_id}</span>
                  {r.parameters?.symbol && (
                    <span className="text-gray-500">
                      {r.parameters.symbol} {r.parameters.period}
                    </span>
                  )}
                </div>
                <span
                  className={
                    r.status === 'done'
                      ? 'text-green-400 text-sm'
                      : r.status === 'failed'
                      ? 'text-red-400 text-sm'
                      : 'text-yellow-400 text-sm'
                  }
                >
                  {r.status}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
