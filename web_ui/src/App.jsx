import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuthStore } from './store/authStore'
import Sidebar from './components/Sidebar'
import BottomNav from './components/BottomNav'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import FileManager from './pages/FileManager'
import Compiler from './pages/Compiler'
import BacktestSetup from './pages/BacktestSetup'
import BacktestMonitor from './pages/BacktestMonitor'
import Results from './pages/Results'
import TradeLedger from './pages/TradeLedger'
import History from './pages/History'
import UsageLog from './pages/UsageLog'
import Settings from './pages/Settings'
import SetupWizard from './pages/SetupWizard'

function ProtectedLayout({ children }) {
  const { token } = useAuthStore()
  if (!token) return <Navigate to="/login" replace />
  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <main className="flex-1 overflow-auto pb-16 md:pb-0 min-w-0">
        {children}
      </main>
      <BottomNav />
    </div>
  )
}

const P = (Component) => (
  <ProtectedLayout>
    <Component />
  </ProtectedLayout>
)

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="/dashboard"           element={P(Dashboard)} />
      <Route path="/files"               element={P(FileManager)} />
      <Route path="/compiler"            element={P(Compiler)} />
      <Route path="/backtest/setup"      element={P(BacktestSetup)} />
      <Route path="/backtest/monitor/:runId" element={P(BacktestMonitor)} />
      <Route path="/results"             element={P(Results)} />
      <Route path="/ledger"              element={P(TradeLedger)} />
      <Route path="/history"             element={P(History)} />
      <Route path="/usage"               element={P(UsageLog)} />
      <Route path="/settings"            element={P(Settings)} />
      <Route path="/setup"               element={P(SetupWizard)} />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  )
}
