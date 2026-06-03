import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { listEAs } from '../api/ea'
import { runBacktest } from '../api/backtest'
import { useBacktestStore } from '../store/backtestStore'
import { PlayCircle } from 'lucide-react'

const PERIODS = ['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN1']
const MODELS = [
  { value: 0, label: 'Every Tick' },
  { value: 1, label: '1 Minute OHLC' },
  { value: 2, label: 'Open Prices Only' },
  { value: 3, label: 'Math Calculations' },
  { value: 4, label: 'Real Ticks' },
]

export default function BacktestSetup() {
  const [eas, setEAs] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [form, setForm] = useState({
    ea_id: '',
    symbol: 'EURUSD',
    period: 'H1',
    from_date: '2024.01.01',
    to_date: '2024.12.31',
    model: 1,
    deposit: 10000,
    currency: 'USD',
    leverage: 100,
  })
  const { setActiveRun } = useBacktestStore()
  const nav = useNavigate()

  useEffect(() => { listEAs().then((r) => setEAs(r.data)) }, [])

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }))

  const submit = async (e) => {
    e.preventDefault()
    if (!form.ea_id) { setError('Please select an EA'); return }
    setError('')
    setLoading(true)
    try {
      const { data } = await runBacktest({ ...form, ea_id: +form.ea_id })
      setActiveRun(data.run_id)
      nav(`/backtest/monitor/${data.run_id}`)
    } catch (err) {
      setError(err.response?.data?.detail || 'Failed to start backtest')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="p-6 max-w-xl">
      <h1 className="page-header">Backtest Setup</h1>

      <form onSubmit={submit} className="space-y-5">
        <div className="card space-y-4">
          <h2 className="text-sm font-semibold text-gray-300">Expert Advisor</h2>
          <div>
            <label className="block text-xs text-gray-500 mb-1">Select EA</label>
            <select
              value={form.ea_id}
              onChange={(e) => set('ea_id', e.target.value)}
              className="input-field"
              required
            >
              <option value="">Choose an Expert Advisor...</option>
              {eas.map((ea) => (
                <option key={ea.id} value={ea.id}>{ea.name}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="card space-y-4">
          <h2 className="text-sm font-semibold text-gray-300">Test Parameters</h2>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs text-gray-500 mb-1">Symbol</label>
              <input
                type="text"
                value={form.symbol}
                onChange={(e) => set('symbol', e.target.value)}
                className="input-field"
                placeholder="EURUSD"
              />
            </div>
            <div>
              <label className="block text-xs text-gray-500 mb-1">Timeframe</label>
              <select value={form.period} onChange={(e) => set('period', e.target.value)} className="input-field">
                {PERIODS.map((p) => <option key={p}>{p}</option>)}
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs text-gray-500 mb-1">From Date</label>
              <input
                type="text"
                value={form.from_date}
                onChange={(e) => set('from_date', e.target.value)}
                placeholder="2024.01.01"
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-xs text-gray-500 mb-1">To Date</label>
              <input
                type="text"
                value={form.to_date}
                onChange={(e) => set('to_date', e.target.value)}
                placeholder="2024.12.31"
                className="input-field"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs text-gray-500 mb-1">Testing Model</label>
            <select
              value={form.model}
              onChange={(e) => set('model', +e.target.value)}
              className="input-field"
            >
              {MODELS.map((m) => (
                <option key={m.value} value={m.value}>{m.label}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="card space-y-4">
          <h2 className="text-sm font-semibold text-gray-300">Account</h2>
          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="block text-xs text-gray-500 mb-1">Deposit</label>
              <input
                type="number"
                value={form.deposit}
                onChange={(e) => set('deposit', +e.target.value)}
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-xs text-gray-500 mb-1">Currency</label>
              <input
                type="text"
                value={form.currency}
                onChange={(e) => set('currency', e.target.value)}
                className="input-field"
                placeholder="USD"
              />
            </div>
            <div>
              <label className="block text-xs text-gray-500 mb-1">Leverage</label>
              <input
                type="number"
                value={form.leverage}
                onChange={(e) => set('leverage', +e.target.value)}
                className="input-field"
              />
            </div>
          </div>
        </div>

        {error && (
          <div className="text-red-400 text-sm bg-red-950/30 border border-red-900/50 rounded-lg px-3 py-2">
            {error}
          </div>
        )}

        <button
          type="submit"
          disabled={loading}
          className="btn-primary w-full py-3 flex items-center justify-center gap-2"
        >
          <PlayCircle size={16} />
          {loading ? 'Starting Backtest...' : 'Run Backtest'}
        </button>
      </form>
    </div>
  )
}
