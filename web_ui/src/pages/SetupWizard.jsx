import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../api/client'
import { CheckCircle, Loader } from 'lucide-react'

const STEPS = [
  { id: 'detect',  label: 'Detect MT5' },
  { id: 'dirs',    label: 'Configure Directories' },
  { id: 'key',     label: 'API Key' },
  { id: 'done',    label: 'Complete' },
]

export default function SetupWizard() {
  const [step, setStep] = useState(0)
  const [health, setHealth] = useState(null)
  const [detecting, setDetecting] = useState(false)
  const nav = useNavigate()

  const detect = async () => {
    setDetecting(true)
    try {
      const { data } = await api.get('/health')
      setHealth(data)
      setStep(1)
    } catch (err) {
      alert('Could not reach platform. Is the server running?')
    } finally {
      setDetecting(false)
    }
  }

  return (
    <div className="p-6 max-w-lg space-y-6">
      <h1 className="page-header">Setup Wizard</h1>

      {/* Progress bar */}
      <div className="flex items-center gap-2">
        {STEPS.map((s, i) => (
          <div key={s.id} className="flex-1 flex flex-col items-center gap-1">
            <div
              className={`w-full h-1 rounded-full transition-colors ${
                i <= step ? 'bg-brand-500' : 'bg-gray-800'
              }`}
            />
            <span className={`text-xs ${i === step ? 'text-white' : 'text-gray-600'}`}>
              {s.label}
            </span>
          </div>
        ))}
      </div>

      <div className="card space-y-4">
        {step === 0 && (
          <>
            <h2 className="font-semibold">Step 1: Detect MT5 Installation</h2>
            <p className="text-sm text-gray-400">
              The platform will scan your system for MetaTrader 5 installations using a 5-tier
              detection strategy (Registry → Known Paths → AppData → PATH → Glob scan).
            </p>
            <button
              onClick={detect}
              disabled={detecting}
              className="btn-primary flex items-center gap-2"
            >
              {detecting ? <Loader size={14} className="animate-spin" /> : null}
              {detecting ? 'Detecting...' : 'Detect MT5'}
            </button>
          </>
        )}

        {step === 1 && health && (
          <>
            <h2 className="font-semibold">Step 2: Platform Status</h2>
            <div className="space-y-2 text-sm">
              {[
                { label: 'terminal64.exe', ok: health.terminal_ok, value: health.terminal_path },
                { label: 'MetaEditor64.exe', ok: health.metaeditor_ok, value: health.metaeditor_path },
                { label: 'MQL5 Root', ok: health.mql5_ok, value: health.mql5_root },
              ].map(({ label, ok, value }) => (
                <div key={label} className="flex items-start gap-2">
                  <CheckCircle size={14} className={`mt-0.5 shrink-0 ${ok ? 'text-green-400' : 'text-red-400'}`} />
                  <div>
                    <span className="text-gray-400">{label}:</span>{' '}
                    <code className="text-xs text-gray-200">{value || 'Not found'}</code>
                  </div>
                </div>
              ))}
            </div>
            {!health.terminal_ok && (
              <p className="text-xs text-yellow-400">
                MT5 not found. Set paths manually in <code>.env</code> or install MT5 and re-detect.
              </p>
            )}
            <button onClick={() => setStep(2)} className="btn-primary">
              Continue
            </button>
          </>
        )}

        {step === 2 && (
          <>
            <h2 className="font-semibold">Step 3: API Key</h2>
            <p className="text-sm text-gray-400">
              Generate your API key by running the following command in the server terminal:
            </p>
            <div className="bg-gray-950 rounded-lg p-3 font-mono text-sm text-green-400">
              python main.py --setup-key
            </div>
            <p className="text-xs text-gray-500">
              The key is shown once and stored as a bcrypt hash. Keep it secure.
            </p>
            <button onClick={() => setStep(3)} className="btn-primary">
              Done, Continue
            </button>
          </>
        )}

        {step === 3 && (
          <>
            <h2 className="font-semibold">Setup Complete!</h2>
            <div className="flex items-center gap-3 text-green-400">
              <CheckCircle size={24} />
              <span className="text-sm">Platform is ready to use.</span>
            </div>
            <div className="space-y-2">
              <button onClick={() => nav('/dashboard')} className="btn-primary w-full">
                Go to Dashboard
              </button>
              <button onClick={() => nav('/files')} className="btn-secondary w-full">
                Open File Manager
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
