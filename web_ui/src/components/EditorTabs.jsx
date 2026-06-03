import { useRef } from 'react'
import { X, Circle } from 'lucide-react'
import MonacoEditor from '@monaco-editor/react'
import { useFileStore } from '../store/fileStore'

export default function EditorTabs({ onSave }) {
  const { openFiles, activeTab, closeFile, markDirty, openFile } = useFileStore()
  const active = openFiles.find((f) => f.path === activeTab)

  const handleKeyDown = (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
      e.preventDefault()
      onSave?.()
    }
  }

  return (
    <div className="flex flex-col h-full" onKeyDown={handleKeyDown}>
      {/* Tab bar */}
      {openFiles.length > 0 && (
        <div className="flex bg-gray-900 border-b border-gray-800 overflow-x-auto shrink-0">
          {openFiles.map((f) => {
            const filename = f.path.split('/').pop()
            const isActive = f.path === activeTab
            return (
              <div
                key={f.path}
                onClick={() => openFile(f.path, f.content)}
                className={`flex items-center gap-2 px-3 py-2 text-xs cursor-pointer
                  border-r border-gray-800 shrink-0 select-none transition-colors
                  ${isActive
                    ? 'bg-gray-950 text-white border-t-2 border-t-brand-500'
                    : 'text-gray-500 hover:text-gray-200 hover:bg-gray-800'
                  }`}
              >
                {f.dirty && (
                  <Circle size={6} className="fill-brand-400 text-brand-400 shrink-0" />
                )}
                <span className="max-w-[120px] truncate">{filename}</span>
                <X
                  size={12}
                  className="hover:text-red-400 shrink-0"
                  onClick={(e) => {
                    e.stopPropagation()
                    closeFile(f.path)
                  }}
                />
              </div>
            )
          })}
        </div>
      )}

      {/* Editor */}
      <div className="flex-1 overflow-hidden">
        {active ? (
          <MonacoEditor
            height="100%"
            language={
              active.path.endsWith('.mq5') || active.path.endsWith('.mqh') ? 'cpp' : 'plaintext'
            }
            theme="vs-dark"
            value={active.content}
            onChange={(v) => markDirty(active.path, v ?? '')}
            options={{
              fontSize: 13,
              fontFamily: 'JetBrains Mono, Fira Code, monospace',
              minimap: { enabled: false },
              wordWrap: 'on',
              scrollBeyondLastLine: false,
              lineNumbers: 'on',
              renderLineHighlight: 'all',
              tabSize: 3,
            }}
          />
        ) : (
          <div className="flex-1 flex items-center justify-center text-gray-700 text-sm h-full">
            Open a file from the File Manager to start editing
          </div>
        )}
      </div>
    </div>
  )
}
