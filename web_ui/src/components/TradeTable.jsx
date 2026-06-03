import { useState } from 'react'
import { ChevronUp, ChevronDown } from 'lucide-react'

export default function TradeTable({ trades = [] }) {
  const [sortKey, setSortKey] = useState(null)
  const [sortDir, setSortDir] = useState('asc')
  const [page, setPage] = useState(0)
  const PAGE_SIZE = 50

  if (!trades.length) {
    return <div className="text-gray-600 text-sm p-4 text-center">No trades recorded</div>
  }

  const cols = Object.keys(trades[0])

  const handleSort = (col) => {
    if (sortKey === col) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortKey(col)
      setSortDir('asc')
    }
    setPage(0)
  }

  let sorted = [...trades]
  if (sortKey) {
    sorted.sort((a, b) => {
      const va = a[sortKey]
      const vb = b[sortKey]
      const numA = Number(va)
      const numB = Number(vb)
      if (!isNaN(numA) && !isNaN(numB)) {
        return sortDir === 'asc' ? numA - numB : numB - numA
      }
      return sortDir === 'asc'
        ? String(va).localeCompare(String(vb))
        : String(vb).localeCompare(String(va))
    })
  }

  const totalPages = Math.ceil(sorted.length / PAGE_SIZE)
  const paged = sorted.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)

  const PROFIT_COLS = ['profit', 'pnl', 'p_l', 'gain']

  return (
    <div className="space-y-3">
      <div className="overflow-x-auto rounded-xl border border-gray-800">
        <table className="w-full text-xs text-gray-300 min-w-max">
          <thead>
            <tr className="border-b border-gray-800 bg-gray-900">
              {cols.map((c) => (
                <th
                  key={c}
                  onClick={() => handleSort(c)}
                  className="text-left px-3 py-2 text-gray-500 uppercase tracking-wide cursor-pointer hover:text-gray-300 whitespace-nowrap"
                >
                  <span className="flex items-center gap-1">
                    {c}
                    {sortKey === c && (
                      sortDir === 'asc' ? <ChevronUp size={10} /> : <ChevronDown size={10} />
                    )}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {paged.map((row, i) => (
              <tr key={i} className="border-b border-gray-900 hover:bg-gray-800/40">
                {cols.map((c) => {
                  const val = row[c]
                  const isProfit = PROFIT_COLS.includes(c.toLowerCase())
                  const numVal = Number(val)
                  const profitColor = isProfit && !isNaN(numVal)
                    ? numVal >= 0 ? 'text-green-400' : 'text-red-400'
                    : ''
                  return (
                    <td key={c} className={`px-3 py-1.5 whitespace-nowrap ${profitColor}`}>
                      {val !== null && val !== undefined ? String(val) : '—'}
                    </td>
                  )
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between text-xs text-gray-500">
          <span>{sorted.length} trades total</span>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              disabled={page === 0}
              className="px-2 py-1 bg-gray-800 rounded disabled:opacity-40"
            >
              Prev
            </button>
            <span>Page {page + 1} of {totalPages}</span>
            <button
              onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
              disabled={page >= totalPages - 1}
              className="px-2 py-1 bg-gray-800 rounded disabled:opacity-40"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
