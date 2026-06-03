import { create } from 'zustand'

export const useFileStore = create((set) => ({
  tree: null,
  selectedPath: null,
  openFiles: [],
  activeTab: null,

  setTree: (tree) => set({ tree }),
  selectPath: (path) => set({ selectedPath: path }),

  openFile: (path, content) =>
    set((s) => {
      const existing = s.openFiles.find((f) => f.path === path)
      if (existing) return { activeTab: path }
      return {
        openFiles: [...s.openFiles, { path, content, dirty: false }],
        activeTab: path,
      }
    }),

  closeFile: (path) =>
    set((s) => {
      const remaining = s.openFiles.filter((f) => f.path !== path)
      const newActive = remaining.length > 0 ? remaining[remaining.length - 1].path : null
      return { openFiles: remaining, activeTab: newActive }
    }),

  markDirty: (path, content) =>
    set((s) => ({
      openFiles: s.openFiles.map((f) =>
        f.path === path ? { ...f, content, dirty: true } : f
      ),
    })),

  markSaved: (path) =>
    set((s) => ({
      openFiles: s.openFiles.map((f) =>
        f.path === path ? { ...f, dirty: false } : f
      ),
    })),
}))
