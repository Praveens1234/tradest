import {
  LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, ReferenceLine,
} from 'recharts'

export default function EquityChart({ trades = [], initialDeposit = 10000 }) {
  let equity = initialDeposit
  const data = trades.map((t, i) => {
    equity += Number(t.profit || 0)
    return { trade: i + 1, equity: +equity.toFixed(2) }
  })

  const minVal = data.length > 0 ? Math.min(...data.map((d) => d.equity)) : initialDeposit
  const maxVal = data.length > 0 ? Math.max(...data.map((d) => d.equity)) : initialDeposit

  return (
    <div className="card">
      <div className="text-sm font-medium text-gray-300 mb-3">Equity Curve</div>
      {data.length === 0 ? (
        <div className="h-48 flex items-center justify-center text-gray-600 text-sm">
          No trade data available
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={200}>
          <LineChart data={data} margin={{ top: 5, right: 10, left: 0, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#1f2937" />
            <XAxis
              dataKey="trade"
              stroke="#4b5563"
              tick={{ fontSize: 10, fill: '#6b7280' }}
              label={{ value: 'Trade #', position: 'insideBottom', offset: -2, fill: '#4b5563', fontSize: 10 }}
            />
            <YAxis
              stroke="#4b5563"
              tick={{ fontSize: 10, fill: '#6b7280' }}
              domain={[minVal * 0.995, maxVal * 1.005]}
            />
            <Tooltip
              contentStyle={{
                background: '#111827',
                border: '1px solid #374151',
                borderRadius: '8px',
                fontSize: '12px',
              }}
              labelFormatter={(v) => `Trade #${v}`}
              formatter={(v) => [`$${v.toLocaleString()}`, 'Equity']}
            />
            <ReferenceLine y={initialDeposit} stroke="#374151" strokeDasharray="4 4" />
            <Line
              type="monotone"
              dataKey="equity"
              stroke="#3b82f6"
              dot={false}
              strokeWidth={2}
              activeDot={{ r: 4, fill: '#3b82f6' }}
            />
          </LineChart>
        </ResponsiveContainer>
      )}
    </div>
  )
}
