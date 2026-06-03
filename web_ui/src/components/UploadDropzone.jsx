import { useCallback } from 'react'
import { useDropzone } from 'react-dropzone'
import { UploadCloud } from 'lucide-react'

export default function UploadDropzone({
  onDrop,
  accept = {},
  label = 'Drop files here or click to browse',
  className = '',
}) {
  const { getRootProps, getInputProps, isDragActive } = useDropzone({ onDrop, accept })

  return (
    <div
      {...getRootProps()}
      className={`border-2 border-dashed rounded-xl p-6 text-center cursor-pointer transition-all
        ${isDragActive
          ? 'border-brand-500 bg-blue-950/30 scale-[1.01]'
          : 'border-gray-700 hover:border-gray-500 hover:bg-gray-800/30'
        } ${className}`}
    >
      <input {...getInputProps()} />
      <UploadCloud
        size={28}
        className={`mx-auto mb-2 ${isDragActive ? 'text-brand-400' : 'text-gray-600'}`}
      />
      <p className="text-sm text-gray-400">
        {isDragActive ? 'Release to upload...' : label}
      </p>
      <p className="text-xs text-gray-600 mt-1">Supports .mq5, .mqh, and other MT5 files</p>
    </div>
  )
}
