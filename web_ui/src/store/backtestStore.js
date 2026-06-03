import { create } from 'zustand'

export const useBacktestStore = create((set) => ({
  activeRunId: null,
  runStatus: {},
  results: {},

  setActiveRun: (id) => set({ activeRunId: id }),

  updateStatus: (runId, data) =>
    set((s) => ({
      runStatus: { ...s.runStatus, [runId]: data },
    })),

  setResult: (runId, data) =>
    set((s) => ({
      results: { ...s.results, [runId]: data },
    })),
}))
