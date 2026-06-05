import api from './client'

export const getRecentLogs = (limit = 200, level = null, logger = null) => {
  const params = { limit }
  if (level)  params.level  = level
  if (logger) params.logger = logger
  return api.get('/logs/recent', { params })
}

export const clearLogs = () => api.delete('/logs/clear')
