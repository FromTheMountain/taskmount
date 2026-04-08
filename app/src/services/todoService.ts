import { supabase, type Todo, type Label } from '../supabase'

export async function fetchTodos(): Promise<Todo[]> {
  const { data, error } = await supabase.from('todos').select('*, todo_labels(labels(id, name))').order('id')
  if (error) throw error
  return data as Todo[]
}

export async function insertTodo(
  description: string,
  start_date: string | null,
  deadline: string | null,
  priority: number
): Promise<Todo> {
  const { data, error } = await supabase
    .from('todos')
    .insert({
      description,
      start_date,
      deadline,
      priority,
    })
    .select()
    .single()

  if (error) throw error
  return data as Todo
}

export async function insertTodoLabels(
  todoId: number,
  labels: Array<{ id: number; name: string }>
): Promise<void> {
  if (labels.length === 0) return

  const todoLabelsData = labels.map(label => ({
    todo_id: todoId,
    label_id: label.id,
  }))

  const { error } = await supabase.from('todo_labels').insert(todoLabelsData)
  if (error) throw error
}

export async function findOrCreateLabel(labelName: string): Promise<Label> {
  // Try to find existing label (case-insensitive)
  const { data: existingLabel } = await supabase
    .from('labels')
    .select('id, name')
    .ilike('name', labelName)
    .single()

  if (existingLabel) {
    return existingLabel
  }

  // Create new label
  const { data: newLabel, error } = await supabase
    .from('labels')
    .insert({ name: labelName })
    .select()
    .single()

  if (error) throw error
  return newLabel as Label
}

export async function bulkInsertTodos(
  rows: Array<{ description: string; priority: number }>
): Promise<Todo[]> {
  const { data, error } = await supabase.from('todos').insert(rows).select()
  if (error) throw error
  return data as Todo[]
}

export async function fetchAllLabels(): Promise<Label[]> {
  const { data, error } = await supabase.from('labels').select('id, name').order('name')
  if (error) throw error
  return data || []
}

export async function removeTodoLabel(todoId: number, labelId: number): Promise<void> {
  const { error: deleteError } = await supabase
    .from('todo_labels')
    .delete()
    .eq('todo_id', todoId)
    .eq('label_id', labelId)

  if (deleteError) throw deleteError

  // Check if any other todos have this label
  const { count, error: countError } = await supabase
    .from('todo_labels')
    .select('*', { count: 'exact', head: true })
    .eq('label_id', labelId)

  if (countError) throw countError

  // If no todos use this label, delete it
  if (count === 0) {
    const { error: labelError } = await supabase
      .from('labels')
      .delete()
      .eq('id', labelId)

    if (labelError) throw labelError
  }
}
