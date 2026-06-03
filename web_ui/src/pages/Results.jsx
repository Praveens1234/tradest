import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useBacktestStore } from '../store/backtestStore'
import MetricCard from '../components/MetricCard'
import EquityChart from '../components/EquityChart'
import ReportDownloads from '../components/ReportDownloads'
import { getReports } from '../api/backtest'
import { PlayCircle } from 'lucide-react'

export default function Results() {
  const { activeRunId } = useBacktestStore()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(false)
  const nav = useNavigate()

  useEffect(() => {
    if (!activeRunId) return
    setLoading(true)
    getReports(activeRunId)
      .then((r) => setData(r.data))
      .catch(() => setData(null))
      .finally(() => setLoading(false))
  }, [activeRunId])

  if (!activeRunId) {
    return (
      <div className="p-6">
        <h1 className="page-header">Results</h1>
        <div className="card text-gray-500 text-sm">
          No backtest selected.{' '}
          <button onClick={() => nav('/backtest/setup')} className="text-brand-400 hover:underline">
            Run a backtest →
          </button>
        </div>
      </div>
    )
  }

  if (loading) {
    return (
      <div className="p-6">
        <h1 className="page-header">Results</h1>
        <div className="text-gray-500 text-sm">Loading results...</div>
      </div>
    )
  }

  const m = data?.metrics || {}
  const trades = data?.trades || []

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="page-header mb-0">Results — Run #{activeRunId}</h1>
        <button onClick={() => nav('/backtest/setup')} className="btn-secondary flex items-center gap-2">
          <PlayCircle size={14} />
          New Backtest
        </button>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricCard
          label="Net Profit"
          value={m.total_net_profit !== undefined ? `$${Number(m.total_net_profit).toLocaleString()}` : '—'}
          positive={m.total_net_profit > 0}
        />
        <MetricCard
          label="Profit Factor"
          value={m.profit_factor !== undefined ? Number(m.profit_factor).toFixed(2) : '—'}
          positive={m.profit_factor > 1}
        />
        <MetricCard
          label="Max Drawdown"
          value={m.max_drawdown !== undefined ? `${Number(m.max_drawdown).toFixed(1)}%` : '—'}
          positive={false}
        />
        <MetricCard
          label="Total Trades"
          value={m.total_trades ?? trades.length}
        />
      </div>

      {trades.length > 0 && (
        <EquityChart trades={trades} initialDeposit={10000} />
      )}

      <ReportDownloads runId={activeRunId} />
    </div>
  )
}
