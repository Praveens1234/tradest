import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard, FolderOpen, Code2, PlayCircle,
  BarChart2, BookOpen, History, Activity, Settings, Zap,
} from 'lucide-react'

const links = [
  { to: '/dashboard',       icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/files',           icon: FolderOpen,       label: 'File Manager' },
  { to: '/compiler',        icon: Code2,            label: 'Compiler' },
  { to: '/backtest/setup',  icon: PlayCircle,       label: 'Backtest' },
  { to: '/results',         icon: BarChart2,        label: 'Results' },
  { to: '/ledger',          icon: BookOpen,         label: 'Trade Ledger' },
  { to: '/history',         icon: History,          label: 'History' },
  { to: '/usage',           icon: Activity,         label: 'Usage Log' },
  { to: '/settings',        icon: Settings,         label: 'Settings' },
  { to: '/setup',           icon: Zap,             label: 'Setup Wizard' },
]

export default function Sidebar() {
  return (
    <aside className="hidden md:flex w-56 min-h-screen bg-gray-900 border-r border-gray-800 flex-col py-4 shrink-0">
      <div className="px-4 mb-6">
        <span className="text-lg font-bold text-brand-500">MT5 EA Platform</span>
      </div>
      <nav className="flex-1 space-y-0.5 px-2">
        {links.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors
               ${isActive
                 ? 'bg-brand-500 text-white'
                 : 'text-gray-400 hover:bg-gray-800 hover:text-gray-100'
               }`
            }
          >
            <Icon size={16} className="shrink-0" />
            {label}
          </NavLink>
        ))}
      </nav>
      <div className="px-4 py-2 text-xs text-gray-600">v1.0.0</div>
    </aside>
  )
}
