import { useEffect, useRef, useState, useCallback } from 'react'
import { getRecentLogs, clearLogs } from '../api/logs'
import { Wifi, WifiOff, Trash2, RefreshCw, ChevronDown } from 'lucide-react'

const LEVELS = ['ALL', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']

const levelStyle = {
  DEBUG:    'text-gray-400 bg-gray-800',
  INFO:     'text-blue-300 bg-blue-900/30',
  WARNING:  'text-yellow-300 bg-yellow-900/30',
  ERROR:    'text-red-300 bg-red-900/30',
  CRITICAL: 'text-red-200 bg-red-950 font-bold',
}

const rowStyle = {
  DEBUG:    'hover:bg-gray-800/30',
  INFO:     'hover:bg-blue-900/10',
  WARNING:  'hover:bg-yellow-900/10',
  ERROR:    'hover:bg-red-900/10',
  CRITICAL: 'bg-red-950/20 hover:bg-red-900/20',
}

export default function Logs() {
  const [logs, setLogs]           = useState([])
  const [loading, setLoading]     = useState(true)
  const [level, setLevel]         = useState('ALL')
  const [loggerFilter, setLogger] = useState('')
  const [liveMode, setLiveMode]   = useState(false)
  const [wsState, setWsState]     = useState('disconnected') // connecting connected disconnected
  const [autoScroll, setAutoScroll] = useState(true)
  const [expanded, setExpanded]   = useState(null)

  const bottomRef = useRef(null)
  const wsRef     = useRef(null)

  const fetchLogs = useCallback(async () => {
    setLoading(true)
    try {
      const { data } = await getRecentLogs(300, level === 'ALL' ? null : level, loggerFilter || null)
      setLogs(data)
    } finally {
      setLoading(false)
    }
  }, [level, loggerFilter])

  useEffect(() => { fetchLogs() }, [fetchLogs])

  // Auto-scroll to bottom when new entries arrive
  useEffect(() => {
    if (autoScroll && bottomRef.current) {
      bottomRef.current.scrollIntoView({ behavior: 'smooth' })
    }
  }, [logs, autoScroll])

  // Live WebSocket tail
  useEffect(() => {
    if (!liveMode) {
      if (wsRef.current) {
        wsRef.current.close()
        wsRef.current = null
        setWsState('disconnected')
      }
      return
    }

    const proto = window.location.protocol === 'https:' ? 'wss' : 'ws'
    const base  = import.meta.env.DEV ? `${proto}://localhost:8000` : `${proto}://${window.location.host}`
    const ws    = new WebSocket(`${base}/ws/logs`)
    wsRef.current = ws
    setWsState('connecting')

    ws.onopen  = () => setWsState('connected')
    ws.onclose = () => setWsState('disconnected')
    ws.onerror = () => setWsState('disconnected')

    ws.onmessage = (ev) => {
      try {
        const entry = JSON.parse(ev.data)
        const matchLevel  = level === 'ALL' || entry.level === level
        const matchLogger = !loggerFilter || (entry.logger_name || '').includes(loggerFilter)
        if (matchLevel && matchLogger) {
          setLogs((prev) => [entry, ...prev].slice(0, 500))
        }
      } catch { /* ignore parse errors */ }
    }

    return () => {
      ws.close()
      wsRef.current = null
    }
  }, [liveMode, level, loggerFilter])

  const handleClear = async () => {
    if (!window.confirm('Clear all platform logs from the database?')) return
    await clearLogs()
    setLogs([])
  }

  const wsIcon = wsState === 'connected'
    ? <Wifi size={14} className="text-green-400" />
    : wsState === 'connecting'
    ? <Wifi size={14} className="text-yellow-400 animate-pulse" />
    : <WifiOff size={14} className="text-gray-500" />

  const filtered = liveMode ? logs : logs  // already filtered server-side; live adds client-side filter above

  return (
    <div className="p-6 flex flex-col gap-4 h-full">
      {/* Header */}
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="page-header mb-0 flex-1">Platform Logs</h1>
        <span className="text-xs text-gray-500">{filtered.length} entries</span>

        <button
          onClick={fetchLogs}
          disabled={loading}
          title="Refresh"
          className="btn-secondary flex items-center gap-1.5 text-xs py-1.5 px-3"
        >
          <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
          Refresh
        </button>

        <button
          onClick={handleClear}
          title="Clear logs"
          className="flex items-center gap-1.5 text-xs py-1.5 px-3 bg-gray-800 hover:bg-red-900/40 hover:text-red-300 rounded-lg transition-colors"
        >
          <Trash2 size={13} />
          Clear
        </button>
      </div>

      {/* Controls row */}
      <div className="flex flex-wrap gap-3 items-center">
        {/* Level tabs */}
        <div className="flex gap-1 bg-gray-900 rounded-lg p-1 border border-gray-800">
          {LEVELS.map((l) => (
            <button
              key={l}
              onClick={() => setLevel(l)}
              className={`text-xs px-2.5 py-1 rounded-md transition-colors ${
                level === l
                  ? 'bg-brand-500 text-white'
                  : 'text-gray-400 hover:text-gray-200'
              }`}
            >
              {l}
            </button>
          ))}
        </div>

        {/* Logger filter */}
        <input
          type="text"
          placeholder="Filter by logger name..."
          value={loggerFilter}
          onChange={(e) => setLogger(e.target.value)}
          className="input-field text-xs w-52"
        />

        {/* Live tail toggle */}
        <label className="flex items-center gap-2 cursor-pointer select-none ml-auto">
          <div
            onClick={() => setLiveMode((v) => !v)}
            className={`relative w-10 h-5 rounded-full transition-colors ${
              liveMode ? 'bg-green-600' : 'bg-gray-700'
            }`}
          >
            <div className={`absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${
              liveMode ? 'translate-x-5' : ''
            }`} />
          </div>
          <span className="text-sm text-gray-400 flex items-center gap-1.5">
            {wsIcon}
            Live tail
          </span>
        </label>

        {/* Auto-scroll toggle */}
        {liveMode && (
          <label className="flex items-center gap-2 cursor-pointer select-none text-sm text-gray-400">
            <input
              type="checkbox"
              checked={autoScroll}
              onChange={(e) => setAutoScroll(e.target.checked)}
              className="accent-brand-500"
            />
            Auto-scroll
          </label>
        )}
      </div>

      {/* Log table */}
      <div className="flex-1 overflow-auto rounded-xl border border-gray-800 min-h-0">
        {loading && !liveMode ? (
          <div className="flex items-center justify-center py-20 text-gray-500 text-sm">
            Loading logs...
          </div>
        ) : filtered.length === 0 ? (
          <div className="flex items-center justify-center py-20 text-gray-600 text-sm">
            No log entries found.
          </div>
        ) : (
          <table className="w-full text-xs">
            <thead className="sticky top-0 z-10">
              <tr className="bg-gray-900 border-b border-gray-800">
                {['Level', 'Logger', 'Message', 'Timestamp'].map((h) => (
                  <th key={h} className="text-left px-3 py-2.5 text-gray-500 uppercase tracking-wide whitespace-nowrap font-medium">
                    {h}
                  </th>
                ))}
                <th className="w-6" />
              </tr>
            </thead>
            <tbody>
              {filtered.map((entry) => (
                <>
                  <tr
                    key={entry.id}
                    onClick={() => setExpanded(expanded === entry.id ? null : entry.id)}
                    className={`border-b border-gray-900/80 cursor-pointer transition-colors ${rowStyle[entry.level] || 'hover:bg-gray-800/20'}`}
                  >
                    <td className="px-3 py-2 whitespace-nowrap">
                      <span className={`px-2 py-0.5 rounded text-xs font-mono ${levelStyle[entry.level] || 'bg-gray-800 text-gray-400'}`}>
                        {entry.level}
                      </span>
                    </td>
                    <td className="px-3 py-2 font-mono text-gray-400 whitespace-nowrap max-w-[180px] truncate">
                      {entry.logger_name}
                    </td>
                    <td className="px-3 py-2 text-gray-200 max-w-xs truncate">
                      {entry.message}
                    </td>
                    <td className="px-3 py-2 text-gray-600 whitespace-nowrap">
                      {entry.timestamp ? new Date(entry.timestamp).toLocaleString() : '—'}
                    </td>
                    <td className="px-3 py-2">
                      <ChevronDown
                        size={12}
                        className={`text-gray-600 transition-transform ${expanded === entry.id ? 'rotate-180' : ''}`}
                      />
                    </td>
                  </tr>
                  {expanded === entry.id && (
                    <tr key={`${entry.id}-detail`} className="bg-gray-900/60">
                      <td colSpan={5} className="px-6 py-3 font-mono text-xs text-gray-300">
                        <div className="mb-1 text-gray-100 break-all">{entry.message}</div>
                        {entry.context && Object.keys(entry.context).length > 0 && (
                          <pre className="mt-2 text-gray-500 overflow-auto max-h-40 whitespace-pre-wrap">
                            {JSON.stringify(entry.context, null, 2)}
                          </pre>
                        )}
                      </td>
                    </tr>
                  )}
                </>
              ))}
            </tbody>
          </table>
        )}
        <div ref={bottomRef} />
      </div>
    </div>
  )
}
