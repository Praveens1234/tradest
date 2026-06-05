import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard, FolderOpen, Code2, PlayCircle,
  BarChart2, BookOpen, History, Activity, Settings, Zap, ScrollText,
} from 'lucide-react'

const groups = [
  {
    label: 'Workspace',
    links: [
      { to: '/dashboard',      icon: LayoutDashboard, label: 'Dashboard' },
      { to: '/files',          icon: FolderOpen,      label: 'File Manager' },
      { to: '/compiler',       icon: Code2,           label: 'Compiler' },
    ],
  },
  {
    label: 'Backtesting',
    links: [
      { to: '/backtest/setup', icon: PlayCircle,      label: 'Backtest' },
      { to: '/results',        icon: BarChart2,       label: 'Results' },
      { to: '/ledger',         icon: BookOpen,        label: 'Trade Ledger' },
      { to: '/history',        icon: History,         label: 'History' },
    ],
  },
  {
    label: 'System',
    links: [
      { to: '/logs',           icon: ScrollText,      label: 'Logs' },
      { to: '/usage',          icon: Activity,        label: 'Usage Log' },
      { to: '/settings',       icon: Settings,        label: 'Settings' },
      { to: '/setup',          icon: Zap,             label: 'Setup Wizard' },
    ],
  },
]

export default function Sidebar() {
  return (
    <aside className="hidden md:flex w-56 min-h-screen bg-gray-900 border-r border-gray-800 flex-col py-4 shrink-0">
      <div className="px-4 mb-5">
        <span className="text-base font-bold text-brand-500 tracking-tight">MT5 EA Platform</span>
        <div className="text-xs text-gray-600 mt-0.5">v1.0.0</div>
      </div>
      <nav className="flex-1 px-2 space-y-4 overflow-y-auto">
        {groups.map(({ label, links }) => (
          <div key={label}>
            <div className="px-3 mb-1 text-[10px] font-semibold uppercase tracking-widest text-gray-600">
              {label}
            </div>
            <div className="space-y-0.5">
              {links.map(({ to, icon: Icon, label: lbl }) => (
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
                  <Icon size={15} className="shrink-0" />
                  {lbl}
                </NavLink>
              ))}
            </div>
          </div>
        ))}
      </nav>
    </aside>
  )
}
