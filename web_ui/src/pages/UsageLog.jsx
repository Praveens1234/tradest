import { useEffect, useState, useCallback } from 'react'
import api from '../api/client'
import { RefreshCw } from 'lucide-react'

const ACTION_COLORS = {
  compile:  'text-blue-300',
  backtest: 'text-purple-300',
  upload:   'text-cyan-300',
  delete:   'text-red-300',
}

export default function UsageLog() {
  const [events, setEvents]   = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter]   = useState('')
  const [autoRefresh, setAutoRefresh] = useState(false)

  const fetchEvents = useCallback(() => {
    setLoading(true)
    api.get('/usage/events?limit=300')
      .then((r) => setEvents(r.data))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    fetchEvents()
  }, [fetchEvents])

  // Auto-refresh every 10 seconds when enabled
  useEffect(() => {
    if (!autoRefresh) return
    const id = setInterval(fetchEvents, 10_000)
    return () => clearInterval(id)
  }, [autoRefresh, fetchEvents])

  const lowerFilter = filter.toLowerCase()
  const filtered = filter
    ? events.filter(
        (e) =>
          e.action.toLowerCase().includes(lowerFilter) ||
          e.interface.toLowerCase().includes(lowerFilter) ||
          (e.status || '').toLowerCase().includes(lowerFilter),
      )
    : events

  const actionColor = (action) => {
    for (const [key, cls] of Object.entries(ACTION_COLORS)) {
      if (action.toLowerCase().includes(key)) return cls
    }
    return 'text-gray-300'
  }

  return (
    <div className="p-6 space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="page-header mb-0 flex-1">Usage Log</h1>
        <span className="text-xs text-gray-500">{filtered.length} events</span>

        <button
          onClick={fetchEvents}
          disabled={loading}
          className="btn-secondary flex items-center gap-1.5 text-xs py-1.5 px-3"
        >
          <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
          Refresh
        </button>

        <label className="flex items-center gap-2 cursor-pointer select-none text-sm text-gray-400">
          <div
            onClick={() => setAutoRefresh((v) => !v)}
            className={`relative w-9 h-5 rounded-full transition-colors ${autoRefresh ? 'bg-green-600' : 'bg-gray-700'}`}
          >
            <div className={`absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${autoRefresh ? 'translate-x-4' : ''}`} />
          </div>
          Auto-refresh
        </label>
      </div>

      <input
        type="text"
        placeholder="Filter by action, interface, or status..."
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        className="input-field max-w-sm text-sm"
      />

      {loading && events.length === 0 ? (
        <div className="text-gray-500 text-sm py-8 text-center">Loading...</div>
      ) : filtered.length === 0 ? (
        <div className="text-gray-500 text-sm py-8 text-center">No events found.</div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-gray-800">
          <table className="w-full text-xs text-gray-300">
            <thead>
              <tr className="border-b border-gray-800 bg-gray-900">
                {['Interface', 'Action', 'Status', 'Duration', 'EA', 'Run', 'Timestamp'].map((h) => (
                  <th key={h} className="text-left px-3 py-2.5 text-gray-500 uppercase tracking-wide whitespace-nowrap font-medium">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((e) => (
                <tr key={e.id} className="border-b border-gray-900 hover:bg-gray-800/40 transition-colors">
                  <td className="px-3 py-2">
                    <span className="px-1.5 py-0.5 bg-gray-800 rounded text-gray-400 font-mono">
                      {e.interface}
                    </span>
                  </td>
                  <td className={`px-3 py-2 font-mono font-medium ${actionColor(e.action)}`}>{e.action}</td>
                  <td className={`px-3 py-2 font-medium ${e.status === 'ok' ? 'text-green-400' : 'text-red-400'}`}>
                    {e.status}
                  </td>
                  <td className="px-3 py-2 text-gray-500">
                    {e.duration_ms != null ? `${e.duration_ms}ms` : '—'}
                  </td>
                  <td className="px-3 py-2 text-gray-500">{e.ea_id ?? '—'}</td>
                  <td className="px-3 py-2 text-gray-500">{e.run_id ?? '—'}</td>
                  <td className="px-3 py-2 text-gray-600 whitespace-nowrap">
                    {new Date(e.timestamp).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
