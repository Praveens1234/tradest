import api from './client'

export const runBacktest = (params) => api.post('/backtest/run', params)
export const getStatus = (id) => api.get(`/backtest/${id}/status`)
export const getResult = (id) => api.get(`/backtest/${id}/result`)
export const getReports = (id) => api.get(`/backtest/${id}/reports`)
export const cancelBacktest = (id) => api.delete(`/backtest/${id}/cancel`)
export const getHistory = (skip = 0, limit = 50) =>
  api.get('/backtest/history', { params: { skip, limit } })

export const reportHtmlUrl = (id) => `/backtest/${id}/report/html`
export const reportExcelUrl = (id) => `/backtest/${id}/report/excel`
export const reportCsvUrl = (id) => `/backtest/${id}/report/csv`
