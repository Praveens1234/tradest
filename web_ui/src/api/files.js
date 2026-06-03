import api from './client'

export const getTree = (path = '', depth = 8) =>
  api.get('/files/tree', { params: { path, depth } })

export const listDir = (path) =>
  api.get('/files/list', { params: { path } })

export const readFile = (path) =>
  api.get('/files/read', { params: { path } })

export const getMeta = (path) =>
  api.get('/files/meta', { params: { path } })

export const searchFiles = (q, path = '') =>
  api.get('/files/search', { params: { q, path } })

export const downloadFile = (path) =>
  api.get('/files/download', { params: { path }, responseType: 'blob' })

export const downloadZip = (path) =>
  api.get('/files/download-zip', { params: { path }, responseType: 'blob' })

export const writeFile = (path, content, override = false) =>
  api.post('/files/write', { path, content, override })

export const uploadFile = (path, file, override = false, newName = '') => {
  const fd = new FormData()
  fd.append('file', file)
  return api.post(`/files/upload?path=${encodeURIComponent(path)}&override=${override}&new_name=${newName}`, fd)
}

export const mkdir = (path) => api.post('/files/mkdir', { path })

export const renameFile = (path, new_name, override = false) =>
  api.put('/files/rename', { path, new_name, override })

export const copyFile = (source, destination, override = false) =>
  api.put('/files/copy', { source, destination, override })

export const moveFile = (source, destination, override = false) =>
  api.put('/files/move', { source, destination, override })

export const deleteFile = (path, soft = true) =>
  api.delete('/files/delete', { data: { path, soft } })
