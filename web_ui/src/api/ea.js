import api from './client'

export const listEAs = () => api.get('/ea/list')
export const getEA = (id) => api.get(`/ea/${id}`)
export const createEA = (data) => api.post('/ea/create', data)
export const uploadEA = (formData) => api.post('/ea/upload', formData)
export const updateEA = (id, content) => api.put(`/ea/${id}`, { content })
export const deleteEA = (id) => api.delete(`/ea/${id}`)
export const compileEA = (id) => api.post(`/ea/${id}/compile`)
export const getCompileLogs = (id) => api.get(`/ea/${id}/compile/logs`)
export const getLastCompileLog = (id) => api.get(`/ea/${id}/compile/logs/last`)
