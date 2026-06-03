import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import TradeTable from '../components/TradeTable'
import { getReports, reportCsvUrl } from '../api/backtest'
import { useBacktestStore } from '../store/backtestStore'
import { Download } from 'lucide-react'

export default function TradeLedger() {
  const { activeRunId } = useBacktestStore()
  const [trades, setTrades] = useState([])
  const [loading, setLoading] = useState(false)
  const nav = useNavigate()

  useEffect(() => {
    if (!activeRunId) return
    setLoading(true)
    getReports(activeRunId)
      .then((r) => setTrades(r.data.trades || []))
      .finally(() => setLoading(false))
  }, [activeRunId])

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="page-header mb-0">Trade Ledger</h1>
        {activeRunId && trades.length > 0 && (
          <a
            href={reportCsvUrl(activeRunId)}
            download={`ledger_${activeRunId}.csv`}
            className="btn-secondary flex items-center gap-2"
          >
            <Download size={14} />
            Export CSV
          </a>
        )}
      </div>

      {!activeRunId ? (
        <div className="card text-gray-500 text-sm">
          No run selected.{' '}
          <button onClick={() => nav('/results')} className="text-brand-400 hover:underline">
            Go to Results →
          </button>
        </div>
      ) : loading ? (
        <div className="text-gray-500 text-sm">Loading trades...</div>
      ) : (
        <div className="card p-0 overflow-hidden">
          <TradeTable trades={trades} />
        </div>
      )}
    </div>
  )
}
