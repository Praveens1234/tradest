import api from './client'

export const runBacktest = (params) => api.post('/backtest/run', params)
export const getStatus = (id) => api.get(`/backtest/${id}/status`)
export const getResult = (id) => api.get(`/backtest/${id}/result`)
export const getReports = (id) => api.get(`/backtest/${id}/reports`)
export const cancelBacktest = (id) => api.delete(`/backtest/${id}/cancel`)
export const getHistory = (skip = 0, limit = 50) =>
  api.get('/backtest/history', { params: { skip, limit } })

export const downloadReport = async (id, type, filename) => {
  const res = await api.get(`/backtest/${id}/report/${type}`, { responseType: 'blob' })
  const url = URL.createObjectURL(res.data)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}
