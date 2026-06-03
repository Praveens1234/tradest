import { useState } from 'react'
import { AlertTriangle } from 'lucide-react'

export default function ConflictDialog({ conflict, onOverride, onRename, onCancel }) {
  const [customName, setCustomName] = useState('')

  if (!conflict) return null

  const suggestedName = conflict.suggested_name || conflict.suggestedName || ''

  return (
    <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
      <div className="bg-gray-900 border border-gray-700 rounded-2xl p-6 w-full max-w-md shadow-2xl">
        <div className="flex items-start gap-3 mb-4">
          <AlertTriangle size={20} className="text-yellow-400 shrink-0 mt-0.5" />
          <div>
            <h3 className="font-semibold text-lg">File Already Exists</h3>
            <p className="text-sm text-gray-400 mt-1">
              <code className="text-yellow-300 bg-gray-800 px-1 rounded text-xs">
                {conflict.existing_path || conflict.existingPath}
              </code>{' '}
              already exists in this location.
            </p>
          </div>
        </div>

        <div className="space-y-3">
          <button
            onClick={onOverride}
            className="w-full py-2.5 bg-red-600 hover:bg-red-700 rounded-lg text-sm font-medium transition-colors"
          >
            Overwrite existing file
          </button>

          <div className="flex gap-2">
            <input
              type="text"
              value={customName || suggestedName}
              onChange={(e) => setCustomName(e.target.value)}
              placeholder={suggestedName}
              className="input-field flex-1"
            />
            <button
              onClick={() => onRename(customName || suggestedName)}
              className="btn-primary whitespace-nowrap"
            >
              Save as
            </button>
          </div>

          <button
            onClick={onCancel}
            className="w-full py-2 text-gray-400 hover:text-white text-sm transition-colors"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  )
}
