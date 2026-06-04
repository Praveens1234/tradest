import { useEffect, useState, useCallback } from 'react'
import FileTree from '../components/FileTree'
import EditorTabs from '../components/EditorTabs'
import UploadDropzone from '../components/UploadDropzone'
import ConflictDialog from '../components/ConflictDialog'
import { useFileStore } from '../store/fileStore'
import { getTree, readFile, writeFile, uploadFile, downloadFile } from '../api/files'
import { RefreshCw, Save } from 'lucide-react'

const BINARY_EXTS = new Set([
  'ex5', 'ex4', 'dll', 'exe', 'so', 'bin',
  'zip', 'gz', 'tar', 'rar', '7z',
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'ico',
  'pdf', 'doc', 'docx', 'xls', 'xlsx',
  'mp3', 'mp4', 'avi', 'mov', 'db', 'sqlite',
])

export const BINARY_SENTINEL = '__BINARY_FILE__'

function isBinary(path) {
  return BINARY_EXTS.has(path.split('.').pop().toLowerCase())
}

export default function FileManager() {
  const {
    tree, setTree, selectedPath, selectPath,
    openFile, markSaved, activeTab, openFiles,
  } = useFileStore()
  const [conflict, setConflict] = useState(null)
  const [pendingUpload, setPendingUpload] = useState(null)
  const [saving, setSaving] = useState(false)
  const [loading, setLoading] = useState(true)

  const fetchTree = async () => {
    setLoading(true)
    try {
      const { data } = await getTree()
      setTree(data)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchTree() }, [])

  const handleSelect = async (node) => {
    selectPath(node.path)
    if (!node.is_dir) {
      if (isBinary(node.path)) {
        openFile(node.path, BINARY_SENTINEL)
        return
      }
      try {
        const { data } = await readFile(node.path)
        openFile(node.path, data.content)
      } catch (err) {
        console.error('Failed to read file:', err)
      }
    }
  }

  const handleDownload = async (path) => {
    try {
      const { data } = await downloadFile(path)
      const url = URL.createObjectURL(data)
      const a = document.createElement('a')
      a.href = url
      a.download = path.split('/').pop()
      a.click()
      URL.revokeObjectURL(url)
    } catch (err) {
      console.error('Download failed:', err)
    }
  }

  const handleSave = async () => {
    const active = openFiles.find((f) => f.path === activeTab)
    if (!active || !active.dirty) return
    setSaving(true)
    try {
      await writeFile(active.path, active.content, true)
      markSaved(active.path)
    } catch (err) {
      console.error('Save failed:', err)
    } finally {
      setSaving(false)
    }
  }

  const handleDrop = useCallback(async (files) => {
    for (const file of files) {
      try {
        await uploadFile(selectedPath || '', file, false)
        await fetchTree()
      } catch (err) {
        if (err.response?.status === 409) {
          setConflict(err.response.data)
          setPendingUpload(file)
        }
      }
    }
  }, [selectedPath])

  return (
    <div className="flex h-[calc(100vh-0px)] overflow-hidden">
      {/* Left Panel: Tree + Upload */}
      <div className="w-64 border-r border-gray-800 flex flex-col shrink-0">
        <div className="p-2 border-b border-gray-800 flex items-center gap-2">
          <span className="text-xs text-gray-500 font-medium uppercase tracking-wide flex-1">
            File Manager
          </span>
          <button
            onClick={fetchTree}
            className="p-1 text-gray-600 hover:text-gray-300 transition-colors"
            title="Refresh"
          >
            <RefreshCw size={13} />
          </button>
        </div>

        <div className="p-2 border-b border-gray-800">
          <UploadDropzone
            onDrop={handleDrop}
            label="Drop to upload"
            className="py-3"
          />
        </div>

        <div className="flex-1 overflow-y-auto">
          {loading ? (
            <div className="text-gray-600 text-sm p-4">Loading...</div>
          ) : (
            <FileTree tree={tree} onSelect={handleSelect} selectedPath={selectedPath} />
          )}
        </div>
      </div>

      {/* Right Panel: Editor */}
      <div className="flex-1 flex flex-col overflow-hidden">
        <div className="flex items-center justify-end gap-2 px-3 py-1.5 border-b border-gray-800 bg-gray-900 shrink-0">
          {activeTab && (
            <span className="text-xs text-gray-600 flex-1 truncate">{activeTab}</span>
          )}
          <button
            onClick={handleSave}
            disabled={saving || !openFiles.find((f) => f.path === activeTab)?.dirty}
            className="flex items-center gap-1.5 btn-primary py-1 px-3 text-xs disabled:opacity-30"
          >
            <Save size={12} />
            {saving ? 'Saving...' : 'Save'}
          </button>
        </div>
        <div className="flex-1 overflow-hidden">
          <EditorTabs onSave={handleSave} onDownload={handleDownload} />
        </div>
      </div>

      <ConflictDialog
        conflict={conflict}
        onOverride={async () => {
          if (pendingUpload) {
            await uploadFile(selectedPath || '', pendingUpload, true)
            await fetchTree()
          }
          setConflict(null)
          setPendingUpload(null)
        }}
        onRename={async (name) => {
          if (pendingUpload) {
            const renamed = new File([pendingUpload], name, { type: pendingUpload.type })
            await uploadFile(selectedPath || '', renamed, false)
            await fetchTree()
          }
          setConflict(null)
          setPendingUpload(null)
        }}
        onCancel={() => {
          setConflict(null)
          setPendingUpload(null)
        }}
      />
    </div>
  )
}
