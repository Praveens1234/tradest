import { useParams, useNavigate } from 'react-router-dom'
import BacktestStatus from '../components/BacktestStatus'
import ReportDownloads from '../components/ReportDownloads'
import { ArrowLeft, BarChart2 } from 'lucide-react'
import { useBacktestStore } from '../store/backtestStore'

export default function BacktestMonitor() {
  const { runId } = useParams()
  const rid = parseInt(runId, 10)
  const { runStatus, setActiveRun } = useBacktestStore()
  const nav = useNavigate()
  const status = runStatus[rid]

  const goToResults = () => {
    setActiveRun(rid)
    nav('/results')
  }

  return (
    <div className="p-6 space-y-6 max-w-xl">
      <div className="flex items-center gap-3">
        <button onClick={() => nav('/backtest/setup')} className="text-gray-500 hover:text-white transition-colors">
          <ArrowLeft size={18} />
        </button>
        <h1 className="page-header mb-0">Backtest Monitor</h1>
      </div>

      <BacktestStatus runId={rid} />

      {status?.status === 'done' && (
        <div className="space-y-4">
          <div className="bg-green-950/30 border border-green-800/50 rounded-xl p-4 text-sm text-green-300">
            ✓ Backtest completed successfully!
          </div>
          <button
            onClick={goToResults}
            className="btn-primary flex items-center gap-2"
          >
            <BarChart2 size={14} />
            View Results
          </button>
          <ReportDownloads runId={rid} />
        </div>
      )}

      {status?.status === 'failed' && (
        <div className="bg-red-950/30 border border-red-800/50 rounded-xl p-4 text-sm text-red-300">
          ✗ Backtest failed. Check the logs for details.
        </div>
      )}
    </div>
  )
}
