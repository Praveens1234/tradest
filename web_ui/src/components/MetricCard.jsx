export default function MetricCard({ label, value, unit = '', positive = null, className = '' }) {
  const valueColor =
    positive === null
      ? 'text-white'
      : positive
      ? 'text-green-400'
      : 'text-red-400'

  return (
    <div className={`card ${className}`}>
      <div className="text-xs text-gray-500 uppercase tracking-wide mb-1 truncate">
        {label}
      </div>
      <div className={`text-2xl font-bold ${valueColor} truncate`}>
        {value !== null && value !== undefined ? value : '—'}
        {unit && (
          <span className="text-sm font-normal ml-1 text-gray-400">{unit}</span>
        )}
      </div>
    </div>
  )
}
