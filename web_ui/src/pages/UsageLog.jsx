import { useEffect, useState } from 'react'
import api from '../api/client'

export default function UsageLog() {
  const [events, setEvents] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('')

  useEffect(() => {
    api.get('/usage/events?limit=200')
      .then((r) => setEvents(r.data))
      .finally(() => setLoading(false))
  }, [])

  const filtered = filter
    ? events.filter((e) => e.action.includes(filter) || e.interface.includes(filter))
    : events

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="page-header mb-0">Usage Log</h1>
        <span className="text-sm text-gray-500">{filtered.length} events</span>
      </div>

      <input
        type="text"
        placeholder="Filter by action or interface..."
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        className="input-field max-w-xs"
      />

      {loading ? (
        <div className="text-gray-500 text-sm">Loading...</div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-gray-800">
          <table className="w-full text-xs text-gray-300">
            <thead>
              <tr className="border-b border-gray-800 bg-gray-900">
                {['Interface', 'Action', 'Status', 'Duration', 'EA', 'Run', 'Timestamp'].map((h) => (
                  <th key={h} className="text-left px-3 py-2.5 text-gray-500 uppercase tracking-wide whitespace-nowrap">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((e) => (
                <tr key={e.id} className="border-b border-gray-900 hover:bg-gray-800/40">
                  <td className="px-3 py-2 font-medium">{e.interface}</td>
                  <td className="px-3 py-2 font-mono text-blue-300">{e.action}</td>
                  <td className={`px-3 py-2 ${e.status === 'ok' ? 'text-green-400' : 'text-red-400'}`}>
                    {e.status}
                  </td>
                  <td className="px-3 py-2 text-gray-500">
                    {e.duration_ms ? `${e.duration_ms}ms` : '—'}
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
