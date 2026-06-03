import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import axios from 'axios'
import { useAuthStore } from '../store/authStore'
import { Lock } from 'lucide-react'

export default function Login() {
  const [key, setKey] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { setToken } = useAuthStore()
  const nav = useNavigate()

  const submit = async (e) => {
    e.preventDefault()
    if (!key.trim()) return
    setError('')
    setLoading(true)
    try {
      const { data } = await axios.post('/auth/login', { api_key: key })
      setToken(data.token)
      nav('/dashboard')
    } catch (err) {
      setError(err.response?.data?.detail || 'Invalid API key')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-950 p-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-12 h-12 bg-brand-500/20 rounded-2xl mb-4">
            <Lock size={20} className="text-brand-400" />
          </div>
          <h1 className="text-2xl font-bold">MT5 EA Platform</h1>
          <p className="text-gray-500 text-sm mt-1">Enter your API key to continue</p>
        </div>

        <form
          onSubmit={submit}
          className="bg-gray-900 border border-gray-800 rounded-2xl p-6 space-y-4"
        >
          <div>
            <label className="block text-xs text-gray-500 mb-1.5">API Key</label>
            <input
              type="password"
              placeholder="••••••••••••••••••••••••••••••"
              value={key}
              onChange={(e) => setKey(e.target.value)}
              className="input-field"
              autoFocus
            />
          </div>

          {error && (
            <div className="text-red-400 text-sm bg-red-950/30 border border-red-900/50 rounded-lg px-3 py-2">
              {error}
            </div>
          )}

          <button type="submit" disabled={loading} className="btn-primary w-full py-2.5">
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>

        <p className="text-center text-xs text-gray-600 mt-4">
          Run <code className="text-gray-400">python main.py --setup-key</code> to generate a key
        </p>
      </div>
    </div>
  )
}
