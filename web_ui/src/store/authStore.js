import { create } from 'zustand'

export const useAuthStore = create((set) => ({
  token: sessionStorage.getItem('token') || null,
  setToken: (token) => {
    sessionStorage.setItem('token', token)
    set({ token })
  },
  logout: () => {
    sessionStorage.removeItem('token')
    set({ token: null })
  },
}))
