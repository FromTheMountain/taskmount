import type { Label } from '../supabase'

/**
 * Find a label that matches the start of the given input (case-insensitive)
 */
export function findLabelMatch(input: string, labels: Label[]): Label | undefined {
  const trimmed = input.trim()
  if (!trimmed) return undefined

  return labels.find(label =>
    label.name.toLowerCase().startsWith(trimmed.toLowerCase())
  )
}

/**
 * Apply autocomplete selection to an input element
 * Selects the auto-filled portion so it can be overwritten
 */
export function applyLabelSelection(
  inputElement: HTMLInputElement,
  trimmedLength: number,
  matchLength: number
): void {
  inputElement.setSelectionRange(trimmedLength, matchLength)
}
