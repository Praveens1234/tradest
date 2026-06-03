import { useState } from 'react'
import { Download, FileText, Table, FileSpreadsheet, Loader2 } from 'lucide-react'
import { downloadReport } from '../api/backtest'

export default function ReportDownloads({ runId }) {
  const [loading, setLoading] = useState({})

  if (!runId) return null

  const reports = [
    { label: 'HTML Report', icon: FileText, type: 'html', filename: `report_${runId}.html`, color: 'text-blue-400' },
    { label: 'Excel Report', icon: FileSpreadsheet, type: 'excel', filename: `report_${runId}.xml`, color: 'text-green-400' },
    { label: 'Trade Ledger CSV', icon: Table, type: 'csv', filename: `ledger_${runId}.csv`, color: 'text-yellow-400' },
  ]

  const handleDownload = async (type, filename) => {
    setLoading((p) => ({ ...p, [type]: true }))
    try {
      await downloadReport(runId, type, filename)
    } catch {
      // silent — server returns 404 if report not ready
    } finally {
      setLoading((p) => ({ ...p, [type]: false }))
    }
  }

  return (
    <div className="card">
      <h3 className="text-sm font-medium text-gray-300 mb-3">
        Backtest Reports — Run #{runId}
      </h3>
      <div className="flex flex-wrap gap-2">
        {reports.map(({ label, icon: Icon, type, filename, color }) => (
          <button
            key={type}
            onClick={() => handleDownload(type, filename)}
            disabled={loading[type]}
            className="flex items-center gap-2 px-4 py-2 bg-gray-800 hover:bg-gray-700
              rounded-lg text-sm transition-colors group disabled:opacity-50"
          >
            <Icon size={14} className={`${color} group-hover:scale-110 transition-transform`} />
            <span className="text-gray-200">{label}</span>
            {loading[type]
              ? <Loader2 size={12} className="text-gray-400 animate-spin" />
              : <Download size={12} className="text-gray-500 group-hover:text-gray-300" />}
          </button>
        ))}
      </div>
    </div>
  )
}
