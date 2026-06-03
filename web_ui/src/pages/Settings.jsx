import { useEffect, useState } from 'react'
import api from '../api/client'
import { CheckCircle, XCircle } from 'lucide-react'

function TabBtn({ label, active, onClick }) {
  return (
    <button
      onClick={onClick}
      className={`px-4 py-2 text-sm font-medium rounded-lg transition-colors
        ${active ? 'bg-brand-500 text-white' : 'text-gray-400 hover:text-white hover:bg-gray-800'}`}
    >
      {label}
    </button>
  )
}

export default function Settings() {
  const [tab, setTab] = useState('mt5')
  const [health, setHealth] = useState(null)

  useEffect(() => {
    api.get('/health').then((r) => setHealth(r.data))
  }, [])

  const StatusIcon = ({ ok }) => ok
    ? <CheckCircle size={14} className="text-green-400" />
    : <XCircle size={14} className="text-red-400" />

  return (
    <div className="p-6 space-y-6 max-w-2xl">
      <h1 className="page-header">Settings</h1>

      <div className="flex gap-1 border-b border-gray-800 pb-3">
        {['mt5', 'api', 'workspace', 'lan'].map((t) => (
          <TabBtn key={t} label={t.toUpperCase()} active={tab === t} onClick={() => setTab(t)} />
        ))}
      </div>

      {tab === 'mt5' && (
        <div className="card space-y-4">
          <h2 className="font-semibold">MT5 Configuration</h2>
          {health ? (
            <div className="space-y-3 text-sm">
              <div className="flex items-center gap-2">
                <StatusIcon ok={health.terminal_ok} />
                <span className="text-gray-400">terminal64.exe:</span>
                <code className="text-gray-200 text-xs">{health.terminal_path || 'Not configured'}</code>
              </div>
              <div className="flex items-center gap-2">
                <StatusIcon ok={health.metaeditor_ok} />
                <span className="text-gray-400">MetaEditor64.exe:</span>
                <code className="text-gray-200 text-xs">{health.metaeditor_path || 'Not configured'}</code>
              </div>
              <div className="flex items-center gap-2">
                <StatusIcon ok={health.mql5_ok} />
                <span className="text-gray-400">MQL5 Root:</span>
                <code className="text-gray-200 text-xs">{health.mql5_root || 'Not configured'}</code>
              </div>
            </div>
          ) : (
            <div className="text-gray-500 text-sm">Loading...</div>
          )}
          <div className="text-xs text-gray-600 border-t border-gray-800 pt-3">
            To configure MT5 paths, edit <code className="text-gray-400">.env</code> or run{' '}
            <code className="text-gray-400">python main.py --detect-mt5</code>
          </div>
        </div>
      )}

      {tab === 'api' && (
        <div className="card space-y-4">
          <h2 className="font-semibold">API Key</h2>
          <p className="text-sm text-gray-400">
            API keys are managed via the server CLI.
          </p>
          <div className="bg-gray-950 rounded-lg p-3 text-xs font-mono text-gray-400 space-y-1">
            <div># Generate a new API key:</div>
            <div className="text-green-400">python main.py --setup-key</div>
          </div>
          <div className="text-xs text-gray-600">
            The key is displayed once and stored as a bcrypt hash in <code>.env</code>.
          </div>
        </div>
      )}

      {tab === 'workspace' && (
        <div className="card space-y-4">
          <h2 className="font-semibold">Workspace & Storage</h2>
          <div className="text-sm text-gray-400 space-y-2">
            <div>
              <span className="text-gray-500">Workspace:</span>{' '}
              <code className="text-gray-200">workspace/</code>
            </div>
            <div>
              <span className="text-gray-500">Exports:</span>{' '}
              <code className="text-gray-200">exports/</code>
            </div>
            <div>
              <span className="text-gray-500">Logs:</span>{' '}
              <code className="text-gray-200">logs/</code>
            </div>
            <div>
              <span className="text-gray-500">Trash:</span>{' '}
              <code className="text-gray-200">&lt;mql5_root&gt;/_trash/</code>
            </div>
          </div>
          <div className="text-xs text-gray-600 border-t border-gray-800 pt-3">
            Configure paths via <code className="text-gray-400">WORKSPACE_DIR</code> and{' '}
            <code className="text-gray-400">EXPORTS_DIR</code> in <code className="text-gray-400">.env</code>.
          </div>
        </div>
      )}

      {tab === 'lan' && (
        <div className="card space-y-4">
          <h2 className="font-semibold">LAN Access</h2>
          <div className="text-sm text-gray-400 space-y-2">
            <div>
              <span className="text-gray-500">REST API + Web UI:</span>{' '}
              <code className="text-gray-200">http://&lt;host-ip&gt;:8000</code>
            </div>
            <div>
              <span className="text-gray-500">MCP Server:</span>{' '}
              <code className="text-gray-200">stdio transport (local only)</code>
            </div>
          </div>
          <p className="text-xs text-gray-600">
            The server binds to <code>0.0.0.0</code> by default, making it accessible on your LAN.
            Ensure your firewall allows inbound TCP on port 8000.
          </p>
        </div>
      )}
    </div>
  )
}
