import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_KEY as string

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

export type Label = {
  id: number
  name: string
}

export type Todo = {
  id: number
  description: string
  completed: string | null
  start_date: string | null
  deadline: string | null
  priority: number | null
  todo_labels: Array<{ labels: Label }>
}
