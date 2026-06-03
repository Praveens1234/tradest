import { useEffect, useState } from 'react'
import { useBacktestStore } from '../store/backtestStore'
import { cancelBacktest } from '../api/backtest'
import { Square } from 'lucide-react'

export default function BacktestStatus({ runId }) {
  const { updateStatus } = useBacktestStore()
  const [status, setStatus] = useState(null)
  const [cancelling, setCancelling] = useState(false)

  useEffect(() => {
    if (!runId) return

    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:'
    const ws = new WebSocket(`${proto}//${location.host}/ws/backtest/${runId}`)

    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data)
      setStatus(msg)
      updateStatus(runId, msg)
    }
    ws.onclose = () => {}

    return () => ws.close()
  }, [runId])

  const handleCancel = async () => {
    setCancelling(true)
    try {
      await cancelBacktest(runId)
    } finally {
      setCancelling(false)
    }
  }

  if (!status) {
    return (
      <div className="card">
        <div className="text-gray-500 text-sm">Connecting to backtest #{runId}...</div>
      </div>
    )
  }

  const colorMap = {
    pending:   'text-gray-400',
    running:   'text-yellow-400',
    done:      'text-green-400',
    failed:    'text-red-400',
    cancelled: 'text-gray-500',
  }

  return (
    <div className="card space-y-3">
      <div className="flex items-center justify-between">
        <span className="text-sm text-gray-400">Run #{runId}</span>
        <span className={`text-sm font-bold ${colorMap[status.status] || 'text-white'}`}>
          {status.status?.toUpperCase()}
        </span>
      </div>

      {status.pid && (
        <div className="text-xs text-gray-500">PID: {status.pid}</div>
      )}

      {status.elapsed_s !== undefined && (
        <div className="text-xs text-gray-500">
          Elapsed: {Math.floor(status.elapsed_s / 60)}m {status.elapsed_s % 60}s
        </div>
      )}

      {status.resources && (
        <div className="text-xs text-gray-500">
          CPU: {status.resources.cpu_percent?.toFixed(1)}% |{' '}
          RAM: {status.resources.memory_mb} MB
        </div>
      )}

      {status.status === 'running' && (
        <button
          onClick={handleCancel}
          disabled={cancelling}
          className="flex items-center gap-2 px-3 py-1.5 bg-red-900 hover:bg-red-800 rounded-lg text-xs text-red-300 transition-colors"
        >
          <Square size={12} />
          {cancelling ? 'Cancelling...' : 'Cancel Backtest'}
        </button>
      )}
    </div>
  )
}
