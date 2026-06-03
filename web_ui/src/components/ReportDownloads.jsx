import { Download, FileText, Table, FileSpreadsheet } from 'lucide-react'
import { reportHtmlUrl, reportExcelUrl, reportCsvUrl } from '../api/backtest'

export default function ReportDownloads({ runId }) {
  if (!runId) return null

  const reports = [
    {
      label: 'HTML Report',
      icon: FileText,
      href: reportHtmlUrl(runId),
      filename: `report_${runId}.html`,
      color: 'text-blue-400',
    },
    {
      label: 'Excel Report',
      icon: FileSpreadsheet,
      href: reportExcelUrl(runId),
      filename: `report_${runId}.xml`,
      color: 'text-green-400',
    },
    {
      label: 'Trade Ledger CSV',
      icon: Table,
      href: reportCsvUrl(runId),
      filename: `ledger_${runId}.csv`,
      color: 'text-yellow-400',
    },
  ]

  return (
    <div className="card">
      <h3 className="text-sm font-medium text-gray-300 mb-3">
        Backtest Reports — Run #{runId}
      </h3>
      <div className="flex flex-wrap gap-2">
        {reports.map(({ label, icon: Icon, href, filename, color }) => (
          <a
            key={label}
            href={href}
            download={filename}
            className="flex items-center gap-2 px-4 py-2 bg-gray-800 hover:bg-gray-700
              rounded-lg text-sm transition-colors group"
          >
            <Icon size={14} className={`${color} group-hover:scale-110 transition-transform`} />
            <span className="text-gray-200">{label}</span>
            <Download size={12} className="text-gray-500 group-hover:text-gray-300" />
          </a>
        ))}
      </div>
    </div>
  )
}
