import { NavLink } from 'react-router-dom'
import { LayoutDashboard, FolderOpen, PlayCircle, ScrollText, Settings } from 'lucide-react'

const links = [
  { to: '/dashboard',      icon: LayoutDashboard, label: 'Home' },
  { to: '/files',          icon: FolderOpen,      label: 'Files' },
  { to: '/backtest/setup', icon: PlayCircle,      label: 'Backtest' },
  { to: '/logs',           icon: ScrollText,      label: 'Logs' },
  { to: '/settings',       icon: Settings,        label: 'Settings' },
]

export default function BottomNav() {
  return (
    <nav className="md:hidden fixed bottom-0 inset-x-0 bg-gray-900 border-t border-gray-800 flex z-50">
      {links.map(({ to, icon: Icon, label }) => (
        <NavLink
          key={to}
          to={to}
          className={({ isActive }) =>
            `flex-1 flex flex-col items-center py-2 text-xs transition-colors
             ${isActive ? 'text-brand-500' : 'text-gray-500 hover:text-gray-300'}`
          }
        >
          <Icon size={20} />
          <span className="mt-0.5">{label}</span>
        </NavLink>
      ))}
    </nav>
  )
}
