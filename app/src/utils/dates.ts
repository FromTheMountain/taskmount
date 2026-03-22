export function toDateOnly(iso: string | null): string {
  if (!iso) return ''
  return iso.slice(0, 10)
}

export function toRelativeDate(iso: string | null): string {
  if (!iso) return ''
  const today = new Date().toISOString().slice(0, 10)
  const diffDays = Math.round(
    (new Date(iso.slice(0, 10)).getTime() - new Date(today).getTime()) / 86_400_000
  )
  if (diffDays === 0) return 'today'
  if (diffDays === 1) return 'tomorrow'
  if (diffDays === -1) return 'yesterday'
  if (diffDays > 0) return `in ${diffDays} days`
  return `${Math.abs(diffDays)} days ago`
}

export function toIso(local: string): string | null {
  return local ? new Date(local).toISOString() : null
}
