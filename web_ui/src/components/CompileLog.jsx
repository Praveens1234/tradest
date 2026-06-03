import { useEffect, useRef, useState } from 'react'
import { Terminal } from 'lucide-react'

export default function CompileLog({ eaId, autoConnect = false, staticLines = null }) {
  const [lines, setLines] = useState([])
  const [wsStatus, setWsStatus] = useState('idle')
  const bottomRef = useRef(null)
  const wsRef = useRef(null)

  useEffect(() => {
    if (staticLines) {
      setLines(staticLines)
      return
    }
    if (!autoConnect || !eaId) return

    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:'
    const ws = new WebSocket(`${proto}//${location.host}/ws/compile/${eaId}`)
    wsRef.current = ws
    setWsStatus('connecting')

    ws.onopen = () => setWsStatus('connected')
    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data)
      if (msg.type === 'complete') {
        setWsStatus(msg.status === 'success' ? 'success' : 'error')
      } else {
        setLines((prev) => [...prev, msg])
      }
    }
    ws.onerror = () => setWsStatus('error')
    ws.onclose = () => setWsStatus((s) => (s === 'connected' ? 'closed' : s))

    return () => ws.close()
  }, [eaId, autoConnect, staticLines])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [lines])

  const statusColor = {
    idle: 'text-gray-500',
    connecting: 'text-yellow-400',
    connected: 'text-blue-400',
    success: 'text-green-400',
    error: 'text-red-400',
    closed: 'text-gray-500',
  }

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center gap-2 text-sm font-medium text-gray-300">
          <Terminal size={14} />
          Compile Output
        </div>
        <span className={`text-xs ${statusColor[wsStatus]}`}>{wsStatus}</span>
      </div>
      <div className="bg-black rounded-lg p-3 font-mono text-xs h-64 overflow-y-auto">
        {lines.length === 0 && (
          <span className="text-gray-600">
            {autoConnect ? 'Waiting for compile output...' : 'No output yet.'}
          </span>
        )}
        {lines.map((l, i) => (
          <div
            key={i}
            className={
              l.type === 'error'
                ? 'text-red-400'
                : l.type === 'warning'
                ? 'text-yellow-400'
                : 'text-green-400'
            }
          >
            {l.file && `${l.file}(${l.line},${l.col}): `}
            {l.message || JSON.stringify(l)}
          </div>
        ))}
        <div ref={bottomRef} />
      </div>
    </div>
  )
}
