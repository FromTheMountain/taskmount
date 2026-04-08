import type { Todo } from '../supabase'

export const PRIORITY_STEP = 65536

export function computeNextPriority(todos: Todo[]): number {
  const priorities = todos.map(t => t.priority).filter((p): p is number => p !== null)
  return priorities.length > 0 ? Math.min(...priorities) - PRIORITY_STEP : PRIORITY_STEP
}

export function computeImportPriorities(todos: Todo[], count: number): number[] {
  const priorities = todos.map(t => t.priority).filter((p): p is number => p !== null)
  const basePriority = priorities.length > 0 ? Math.min(...priorities) : PRIORITY_STEP * (count + 1)
  return Array.from({ length: count }, (_, i) => basePriority - (count - i) * PRIORITY_STEP)
}
