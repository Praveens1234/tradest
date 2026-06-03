import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { getHistory } from '../api/backtest'
import { useBacktestStore } from '../store/backtestStore'
import ReportDownloads from '../components/ReportDownloads'
import { ChevronRight } from 'lucide-react'

const statusColor = {
  done:      'bg-green-900/40 text-green-300',
  failed:    'bg-red-900/40 text-red-300',
  running:   'bg-yellow-900/40 text-yellow-300',
  cancelled: 'bg-gray-800 text-gray-500',
  pending:   'bg-blue-900/40 text-blue-300',
}

export default function History() {
  const [runs, setRuns] = useState([])
  const [loading, setLoading] = useState(true)
  const [expanded, setExpanded] = useState(null)
  const { setActiveRun } = useBacktestStore()
  const nav = useNavigate()

  useEffect(() => {
    getHistory(0, 100)
      .then((r) => setRuns(r.data))
      .finally(() => setLoading(false))
  }, [])

  const viewResults = (runId) => {
    setActiveRun(runId)
    nav('/results')
  }

  return (
    <div className="p-6 space-y-4">
      <h1 className="page-header">Backtest History</h1>

      {loading ? (
        <div className="text-gray-500 text-sm">Loading...</div>
      ) : runs.length === 0 ? (
        <div className="card text-gray-500 text-sm">No backtest history yet.</div>
      ) : (
        <div className="space-y-2">
          {runs.map((r) => (
            <div key={r.run_id} className="card">
              <div
                className="flex items-center gap-3 cursor-pointer"
                onClick={() => setExpanded(expanded === r.run_id ? null : r.run_id)}
              >
                <ChevronRight
                  size={14}
                  className={`text-gray-500 shrink-0 transition-transform ${expanded === r.run_id ? 'rotate-90' : ''}`}
                />
                <div className="flex-1 flex flex-wrap items-center gap-x-4 gap-y-1 min-w-0">
                  <span className="font-medium text-sm">Run #{r.run_id}</span>
                  {r.ea_id && <span className="text-gray-500 text-sm">EA #{r.ea_id}</span>}
                  {r.parameters?.ea_name && (
                    <span className="text-gray-400 text-sm">{r.parameters.ea_name}</span>
                  )}
                  {r.parameters?.symbol && (
                    <span className="text-gray-500 text-xs">
                      {r.parameters.symbol} {r.parameters.period}
                    </span>
                  )}
                  {r.started_at && (
                    <span className="text-gray-600 text-xs ml-auto">
                      {new Date(r.started_at).toLocaleString()}
                    </span>
                  )}
                </div>
                <span className={`text-xs px-2 py-0.5 rounded-full ${statusColor[r.status] || 'bg-gray-800 text-gray-400'}`}>
                  {r.status}
                </span>
              </div>

              {expanded === r.run_id && (
                <div className="mt-4 pt-4 border-t border-gray-800 space-y-3">
                  {r.status === 'done' && (
                    <button
                      onClick={() => viewResults(r.run_id)}
                      className="btn-primary text-sm"
                    >
                      View Results
                    </button>
                  )}
                  <ReportDownloads runId={r.run_id} />
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
