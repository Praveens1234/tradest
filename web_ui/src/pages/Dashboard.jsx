import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import MetricCard from '../components/MetricCard'
import { listEAs } from '../api/ea'
import { getHistory } from '../api/backtest'
import api from '../api/client'
import { Code2, PlayCircle, FolderOpen, ScrollText, AlertTriangle, RefreshCw } from 'lucide-react'

function Skeleton({ className = '' }) {
  return <div className={`animate-pulse bg-gray-800 rounded-lg ${className}`} />
}

function QuickAction({ icon: Icon, label, to, nav }) {
  return (
    <button
      onClick={() => nav(to)}
      className="flex flex-col items-center gap-2 p-4 card hover:border-brand-500/50 hover:bg-gray-800/60 transition-all cursor-pointer text-center"
    >
      <div className="w-9 h-9 rounded-xl bg-brand-500/10 flex items-center justify-center">
        <Icon size={18} className="text-brand-400" />
      </div>
      <span className="text-xs text-gray-300">{label}</span>
    </button>
  )
}

export default function Dashboard() {
  const [eas, setEAs]       = useState([])
  const [runs, setRuns]     = useState([])
  const [health, setHealth] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError]   = useState(null)
  const nav = useNavigate()

  const load = () => {
    setLoading(true)
    setError(null)
    Promise.all([
      listEAs().then((r) => setEAs(r.data)),
      getHistory(0, 10).then((r) => setRuns(r.data)),
      api.get('/health').then((r) => setHealth(r.data)),
    ])
      .catch(() => setError('Failed to load dashboard data.'))
      .finally(() => setLoading(false))
  }

  useEffect(load, [])

  const completed = runs.filter((r) => r.status === 'done').length
  const failed    = runs.filter((r) => r.status === 'failed').length

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="page-header mb-0">Dashboard</h1>
        <button
          onClick={load}
          disabled={loading}
          className="btn-secondary flex items-center gap-1.5 text-xs py-1.5 px-3"
        >
          <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      {/* MT5 degraded banner */}
      {health?.status === 'degraded' && (
        <div className="flex items-start gap-3 bg-yellow-950/40 border border-yellow-800/50 rounded-xl px-4 py-3 text-sm text-yellow-300">
          <AlertTriangle size={16} className="mt-0.5 shrink-0" />
          <span>
            MT5 paths are not fully configured — compile and backtest are disabled.{' '}
            <button onClick={() => nav('/settings')} className="underline hover:text-yellow-100">
              Go to Settings →
            </button>
          </span>
        </div>
      )}

      {error && (
        <div className="bg-red-950/40 border border-red-800/50 rounded-xl px-4 py-3 text-sm text-red-300">
          {error}
        </div>
      )}

      {/* Metric cards */}
      {loading ? (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-24" />)}
        </div>
      ) : (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <MetricCard label="EAs Registered"  value={eas.length} />
          <MetricCard label="Total Backtests" value={runs.length} />
          <MetricCard label="Completed"  value={completed} positive={completed > 0} />
          <MetricCard label="Failed"     value={failed}    positive={failed === 0} />
        </div>
      )}

      {/* System health */}
      {loading ? (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-24" />)}
        </div>
      ) : health ? (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          <MetricCard label="CPU Usage"       value={health.cpu_percent?.toFixed(1)}  unit="%" />
          <MetricCard label="RAM Usage"       value={health.memory_mb?.toFixed(0)}    unit="MB" />
          <MetricCard
            label="Platform Status"
            value={health.status === 'ok' ? 'Healthy' : 'Degraded'}
            positive={health.status === 'ok'}
          />
        </div>
      ) : null}

      {/* Quick actions */}
      <div>
        <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-widest mb-3">Quick Actions</h2>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <QuickAction icon={Code2}       label="Open Compiler"   to="/compiler"       nav={nav} />
          <QuickAction icon={PlayCircle}  label="Run Backtest"    to="/backtest/setup" nav={nav} />
          <QuickAction icon={FolderOpen}  label="File Manager"    to="/files"          nav={nav} />
          <QuickAction icon={ScrollText}  label="View Logs"       to="/logs"           nav={nav} />
        </div>
      </div>

      {/* Recent backtests */}
      <div>
        <h2 className="text-base font-semibold mb-3">Recent Backtests</h2>
        {loading ? (
          <div className="space-y-2">
            {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-12" />)}
          </div>
        ) : runs.length === 0 ? (
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
                <div className="flex items-center gap-4 text-sm min-w-0">
                  <span className="font-medium shrink-0">Run #{r.run_id}</span>
                  {r.ea_id && <span className="text-gray-500 shrink-0">EA #{r.ea_id}</span>}
                  {r.parameters?.symbol && (
                    <span className="text-gray-500 text-xs truncate">
                      {r.parameters.symbol} {r.parameters.period}
                    </span>
                  )}
                </div>
                <span
                  className={`text-xs px-2 py-0.5 rounded-full shrink-0 ${
                    r.status === 'done'      ? 'bg-green-900/40 text-green-300'  :
                    r.status === 'failed'    ? 'bg-red-900/40 text-red-300'      :
                    r.status === 'running'   ? 'bg-yellow-900/40 text-yellow-300' :
                    'bg-gray-800 text-gray-400'
                  }`}
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
