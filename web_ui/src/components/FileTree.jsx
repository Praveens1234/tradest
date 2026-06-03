import { useState } from 'react'
import {
  Folder, FolderOpen, FileCode, File,
  ChevronRight, ChevronDown,
} from 'lucide-react'

function TreeNode({ node, onSelect, selectedPath, depth = 0 }) {
  const [open, setOpen] = useState(depth < 2)
  const isSelected = node.path === selectedPath

  const isCode = ['mq5', 'mqh'].includes(node.extension)
  const Icon = node.is_dir
    ? open ? FolderOpen : Folder
    : isCode ? FileCode : File

  const handleClick = () => {
    if (node.is_dir) setOpen((o) => !o)
    onSelect(node)
  }

  return (
    <div>
      <div
        onClick={handleClick}
        className={`flex items-center gap-1.5 py-1 px-2 rounded cursor-pointer text-sm select-none transition-colors
          ${isSelected
            ? 'bg-brand-500 text-white'
            : 'text-gray-300 hover:bg-gray-800 hover:text-white'
          }`}
        style={{ paddingLeft: `${depth * 14 + 8}px` }}
      >
        {node.is_dir && (
          <span className="shrink-0 text-gray-500">
            {open ? <ChevronDown size={12} /> : <ChevronRight size={12} />}
          </span>
        )}
        <Icon
          size={14}
          className={`shrink-0 ${
            node.is_dir
              ? 'text-yellow-400'
              : isCode
              ? 'text-blue-400'
              : 'text-gray-400'
          }`}
        />
        <span className="truncate">{node.name}</span>
        {!node.is_dir && node.size > 0 && (
          <span className="ml-auto text-xs text-gray-600 shrink-0">
            {node.size > 1024 ? `${(node.size / 1024).toFixed(1)}k` : `${node.size}b`}
          </span>
        )}
      </div>

      {node.is_dir && open && node.children?.map((child) => (
        <TreeNode
          key={child.path}
          node={child}
          onSelect={onSelect}
          selectedPath={selectedPath}
          depth={depth + 1}
        />
      ))}
    </div>
  )
}

export default function FileTree({ tree, onSelect, selectedPath }) {
  if (!tree) {
    return <div className="text-gray-600 text-sm p-4">Loading tree...</div>
  }

  const items = tree.children || [tree]
  return (
    <div className="overflow-y-auto py-1">
      {items.map((node) => (
        <TreeNode
          key={node.path}
          node={node}
          onSelect={onSelect}
          selectedPath={selectedPath}
        />
      ))}
    </div>
  )
}
