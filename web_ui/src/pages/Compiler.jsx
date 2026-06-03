import { useEffect, useState } from 'react'
import CompileLog from '../components/CompileLog'
import { listEAs, compileEA, getLastCompileLog } from '../api/ea'
import { Play, CheckCircle, XCircle, AlertCircle } from 'lucide-react'

export default function Compiler() {
  const [eas, setEAs] = useState([])
  const [selectedId, setSelectedId] = useState('')
  const [compiling, setCompiling] = useState(false)
  const [result, setResult] = useState(null)
  const [logLines, setLogLines] = useState(null)

  useEffect(() => { listEAs().then((r) => setEAs(r.data)) }, [])

  const handleCompile = async () => {
    if (!selectedId) return
    setCompiling(true)
    setResult(null)
    setLogLines(null)
    try {
      const { data } = await compileEA(+selectedId)
      setResult(data)
      const lines = []
      for (const e of data.errors || []) lines.push({ type: 'error', ...e })
      for (const w of data.warnings || []) lines.push({ type: 'warning', ...w })
      if (lines.length === 0) lines.push({ type: 'info', message: data.raw_log || 'Compilation successful.' })
      setLogLines(lines)
    } catch (err) {
      setResult({ status: 'error', errors: [{ message: err.response?.data?.detail || 'Compile failed' }] })
    } finally {
      setCompiling(false)
    }
  }

  const StatusIcon = result?.status === 'success'
    ? CheckCircle
    : result?.status === 'warning'
    ? AlertCircle
    : result
    ? XCircle
    : null

  const statusColor = result?.status === 'success'
    ? 'text-green-400 border-green-800 bg-green-950/30'
    : result?.status === 'warning'
    ? 'text-yellow-400 border-yellow-800 bg-yellow-950/30'
    : result
    ? 'text-red-400 border-red-800 bg-red-950/30'
    : ''

  return (
    <div className="p-6 space-y-6 max-w-3xl">
      <h1 className="page-header">Compiler</h1>

      <div className="card space-y-4">
        <div className="flex gap-3">
          <select
            value={selectedId}
            onChange={(e) => setSelectedId(e.target.value)}
            className="input-field flex-1"
          >
            <option value="">Select an Expert Advisor...</option>
            {eas.map((ea) => (
              <option key={ea.id} value={ea.id}>
                {ea.name}.{ea.type}
              </option>
            ))}
          </select>
          <button
            onClick={handleCompile}
            disabled={compiling || !selectedId}
            className="btn-primary flex items-center gap-2 px-5"
          >
            <Play size={14} />
            {compiling ? 'Compiling...' : 'Compile'}
          </button>
        </div>

        {result && (
          <div className={`flex items-center gap-3 p-3 rounded-lg border text-sm ${statusColor}`}>
            {StatusIcon && <StatusIcon size={16} />}
            <span>
              Status: <strong>{result.status}</strong> |{' '}
              Errors: <strong>{result.errors?.length || 0}</strong> |{' '}
              Warnings: <strong>{result.warnings?.length || 0}</strong>
            </span>
          </div>
        )}
      </div>

      {(compiling || logLines) && (
        <CompileLog
          eaId={selectedId ? +selectedId : null}
          autoConnect={compiling}
          staticLines={logLines}
        />
      )}
    </div>
  )
}
