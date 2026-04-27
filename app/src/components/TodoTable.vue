<template>
  <div class="sort-bar">
    <span class="sort-label">Sort by</span>
    <div class="sort-criteria">
      <div v-for="(criterion, index) in sortCriteria" :key="criterion.key" class="sort-chip">
        <span class="sort-chip-label">{{ columnLabel(criterion.key) }}</span>
        <button class="sort-chip-dir" @click="toggleCriterionDir(index)" :title="criterion.dir === 'asc' ? 'Ascending' : 'Descending'">
          {{ criterion.dir === 'asc' ? '↑' : '↓' }}
        </button>
        <button class="sort-chip-remove" @click="removeCriterion(index)" title="Remove">×</button>
      </div>
      <select v-if="availableSortColumns.length" class="sort-add-select" @change="addCriterion(($event.target as HTMLSelectElement).value as SortColumn); ($event.target as HTMLSelectElement).value = ''">
        <option value="" disabled selected>+ Add…</option>
        <option v-for="col in availableSortColumns" :key="col" :value="col">{{ columnLabel(col) }}</option>
      </select>
    </div>
  </div>

  <div class="filter-bar">
    <label class="filter-label">
      <input type="checkbox" v-model="showCompleted" />
      Show completed todos
    </label>
    <label class="filter-label">
      <input type="checkbox" v-model="showFuture" />
      Show future todos
    </label>
  </div>

  <p v-if="loading" class="loading">Loading…</p>

  <div v-else class="table-scroll">
  <table
    class="todo-table"
    @drop.prevent="onDrop"
    @dragover.prevent
    @dragleave="onDragLeave"
  >
    <thead>
      <tr>
        <th class="col-done">Done</th>
        <th class="col-description">Description</th>
        <th class="col-date">Start date</th>
        <th class="col-date">Deadline</th>
        <th class="col-actions"></th>
      </tr>
    </thead>
    <tbody>
      <tr
        v-for="todo in visibleTodos"
        :key="todo.id"
        :class="{
          completed: todo.completed,
          dragging: draggingId === todo.id,
          'drop-before': dropBeforeId === todo.id,
          selected: selectedIds.has(todo.id),
        }"
        draggable="true"
        @click="onRowClick(todo, $event)"
        @dragstart="onDragStart(todo, $event)"
        @dragover="onDragOver(todo, $event)"
        @dragend="onDragEnd"
      >
        <td class="col-done">
          <input
            type="checkbox"
            :checked="!!todo.completed"
            @change="toggleCompleted(todo)"
            class="checkbox"
          />
        </td>
        <td class="col-description">
          <div v-if="editingId !== todo.id" class="description-cell">
            <span class="description-text" @dblclick="startEdit(todo)">
              {{ todo.description }}
            </span>
            <div class="labels-and-add">
              <div v-if="todo.todo_labels?.length" class="labels-container">
                <span v-for="item in todo.todo_labels" :key="item.labels.id" class="label-badge">
                  {{ item.labels.name }}
                  <button
                    type="button"
                    class="label-badge-remove"
                    @click="removeLabelFromTodo(todo, item.labels.id)"
                    title="Remove label"
                  >
                    ×
                  </button>
                </span>
              </div>
              <button
                v-if="addingLabelForTodo !== todo.id"
                type="button"
                class="label-add-btn"
                @click="addingLabelForTodo = todo.id"
                title="Add label"
              >
                <font-awesome-icon icon="plus" />
              </button>
              <div v-else class="label-input-wrapper">
                <input
                  ref="labelInputRef"
                  v-model="newLabelInput"
                  v-focus
                  type="text"
                  placeholder="Label name"
                  class="label-badge-input"
                  @input="onLabelInputChange"
                  @keyup.enter="addLabelToTodo(todo)"
                  @keyup.escape="addingLabelForTodo = null"
                  @blur="addingLabelForTodo = null"
                />
                <span class="label-input-shadow">{{ newLabelInput }}w</span>
              </div>
            </div>
          </div>
          <input
            v-else
            v-model="editDescription"
            class="input inline"
            @keyup.enter="saveEdit(todo)"
            @keyup.escape="editingId = null"
            @blur="saveEdit(todo)"
            autofocus
          />
        </td>
        <td class="col-date">
          <input
            v-if="editingDateKey === `${todo.id}-start_date`"
            type="date"
            :value="toDateOnly(todo.start_date)"
            class="input date-input"
            v-focus
            @change="commitDate(todo, 'start_date', ($event.target as HTMLInputElement).value)"
            @blur="onDateBlur(todo, 'start_date', $event)"
            @keyup.escape="editingDateKey = null"
          />
          <template v-else>
            <span v-if="todo.start_date" class="date-value" @click="editingDateKey = `${todo.id}-start_date`">
              {{ toRelativeDate(todo.start_date) }}
            </span>
            <button v-else class="date-add-btn" @click="editingDateKey = `${todo.id}-start_date`"><font-awesome-icon icon="pencil" /></button>
          </template>
        </td>
        <td class="col-date">
          <input
            v-if="editingDateKey === `${todo.id}-deadline`"
            type="date"
            :value="toDateOnly(todo.deadline)"
            class="input date-input"
            v-focus
            @change="commitDate(todo, 'deadline', ($event.target as HTMLInputElement).value)"
            @blur="onDateBlur(todo, 'deadline', $event)"
            @keyup.escape="editingDateKey = null"
          />
          <template v-else>
            <span v-if="todo.deadline" class="date-value" @click="editingDateKey = `${todo.id}-deadline`">
              {{ toRelativeDate(todo.deadline) }}
            </span>
            <button v-else class="date-add-btn" @click="editingDateKey = `${todo.id}-deadline`"><font-awesome-icon icon="pencil" /></button>
          </template>
        </td>
        <td class="col-actions">
          <button class="btn btn-danger" @click="deleteTodo(todo.id)">Delete</button>
        </td>
      </tr>
      <!-- sentinel row: hovering here means "drop at end" -->
      <tr
        class="drop-sentinel"
        :class="{ 'drop-before': dropBeforeId === 'end' }"
        @dragover.prevent="dropBeforeId = draggingIds.length > 0 && isValidDropPosition('end') ? 'end' : null"
      />
    </tbody>
  </table>
  </div>

  <!-- Confirmation modal -->
  <div v-if="showConfirmModal" class="modal-overlay" @click.self="showConfirmModal = false">
    <div class="modal-content">
      <h2 class="modal-title">Confirm bulk edit</h2>
      <p class="modal-text">You're about to change <strong>{{ selectedIds.size }} {{ selectedIds.size === 1 ? 'todo' : 'todos' }}</strong>:</p>
      <ul class="modal-changes">
        <li v-for="(change, idx) in bulkChangeSummary" :key="idx">{{ change }}</li>
      </ul>
      <p class="modal-warning">This action cannot be undone.</p>
      <div class="modal-actions">
        <button class="btn btn-secondary" @click="showConfirmModal = false">Cancel</button>
        <button class="btn btn-primary" @click="confirmBulkEdit">Confirm</button>
      </div>
    </div>
  </div>

  <!-- Sticky bulk edit bar -->
  <div v-if="selectedIds.size > 0" class="sticky-bulk-bar">
    <div class="bulk-bar-content">
      <span class="bulk-bar-info">{{ selectedIds.size }} {{ selectedIds.size === 1 ? 'todo' : 'todos' }} selected</span>
      <div class="bulk-bar-fields">
        <label class="bulk-field">
          <span class="bulk-label">Mark as done:</span>
          <input type="checkbox" v-model="bulkDone" class="checkbox" />
        </label>
        <label class="bulk-field">
          <span class="bulk-label">Start date:</span>
          <input type="date" v-model="bulkStartDate" class="bulk-date-input" />
        </label>
        <label class="bulk-field">
          <span class="bulk-label">Deadline:</span>
          <input type="date" v-model="bulkDeadline" class="bulk-date-input" />
        </label>
      </div>
      <div class="bulk-bar-actions">
        <button class="btn btn-secondary" @click="clearBulkEdit">Cancel</button>
        <button class="btn btn-primary" @click="showBulkConfirm" :disabled="!hasBulkChanges">Apply</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { supabase, type Todo, type Label } from '../supabase'
import { toDateOnly, toRelativeDate, toIso } from '../utils/dates'
import { PRIORITY_STEP } from '../utils/priority'
import { findOrCreateLabel, insertTodoLabels, removeTodoLabel, fetchAllLabels } from '../services/todoService'
import { findLabelMatch, applyLabelSelection } from '../utils/labelAutocomplete'

const vFocus = { mounted: (el: HTMLElement) => el.focus() }

const props = defineProps<{ todos: Todo[]; loading: boolean }>()
const emit = defineEmits<{
  delete: [id: number]
  error: [message: string]
}>()

// ── Sort ────────────────────────────────────────────────────────────────────

type SortColumn = 'completed' | 'start_date' | 'deadline'
type SortDir = 'asc' | 'desc'
type SortCriterion = { key: SortColumn; dir: SortDir }

const ALL_SORT_COLUMNS: SortColumn[] = ['completed', 'start_date', 'deadline']
const COLUMN_LABELS: Record<SortColumn, string> = {
  completed: 'Completed',
  start_date: 'Start date',
  deadline: 'Deadline',
}

function columnLabel(key: SortColumn): string { return COLUMN_LABELS[key] }

const sortCriteria = ref<SortCriterion[]>([
  { key: 'completed', dir: 'desc' },
  { key: 'deadline', dir: 'asc' },
  { key: 'start_date', dir: 'desc' }
])

const availableSortColumns = computed(() =>
  ALL_SORT_COLUMNS.filter((col) => !sortCriteria.value.some((c) => c.key === col))
)

function addCriterion(key: SortColumn) { sortCriteria.value.push({ key, dir: 'asc' }) }
function removeCriterion(index: number) { sortCriteria.value.splice(index, 1) }
function toggleCriterionDir(index: number) {
  const c = sortCriteria.value[index]
  if (c) c.dir = c.dir === 'asc' ? 'desc' : 'asc'
}

const sortedTodos = computed(() => {
  return [...props.todos].sort((a, b) => {
    const c = compareByActiveCriteria(a, b)
    if (c !== 0) return c
    const ap = a.priority ?? Number.MAX_SAFE_INTEGER
    const bp = b.priority ?? Number.MAX_SAFE_INTEGER
    return ap - bp
  })
})

// ── Filter ──────────────────────────────────────────────────────────────────

const showCompleted = ref(false)
const showFuture = ref(true)
const today = new Date().toISOString().slice(0, 10)

const visibleTodos = computed(() =>
  sortedTodos.value.filter(t => {
    if (!showCompleted.value && t.completed !== null) return false
    if (!showFuture.value && t.start_date !== null && t.start_date.slice(0, 10) > today) return false
    return true
  })
)

// ── Selection ───────────────────────────────────────────────────────────────

const selectedIds = ref<Set<number>>(new Set())
const selectionAnchorIdx = ref<number | null>(null)

function onRowClick(todo: Todo, event: MouseEvent) {
  if ((event.target as HTMLElement).closest('input, button, select')) return
  const idx = visibleTodos.value.findIndex(t => t.id === todo.id)
  if (event.shiftKey && selectionAnchorIdx.value !== null) {
    const from = Math.min(selectionAnchorIdx.value, idx)
    const to = Math.max(selectionAnchorIdx.value, idx)
    const next = new Set<number>()
    for (let i = from; i <= to; i++) {
      const t = visibleTodos.value[i]
      if (t) next.add(t.id)
    }
    selectedIds.value = next
  } else if (event.ctrlKey || event.metaKey) {
    const next = new Set(selectedIds.value)
    if (next.has(todo.id)) {
      next.delete(todo.id)
    } else {
      next.add(todo.id)
    }
    selectedIds.value = next
    selectionAnchorIdx.value = idx
  } else {
    if (selectedIds.value.has(todo.id) && selectedIds.value.size === 1) {
      selectedIds.value = new Set()
      selectionAnchorIdx.value = null
    } else {
      selectedIds.value = new Set([todo.id])
      selectionAnchorIdx.value = idx
    }
  }
}

function onDocumentClick(e: MouseEvent) {
  if (!(e.target as HTMLElement).closest('.todo-table, .sticky-bulk-bar, .modal-overlay')) {
    selectedIds.value = new Set()
    selectionAnchorIdx.value = null
  }
}

// ── Bulk Edit ────────────────────────────────────────────────────────────────

const bulkDone = ref(false)
const bulkDeadline = ref('')
const bulkStartDate = ref('')
const showConfirmModal = ref(false)

const hasBulkChanges = computed(() => {
  return bulkDone.value || bulkDeadline.value || bulkStartDate.value
})

const bulkChangeSummary = computed(() => {
  const changes: string[] = []
  if (bulkDone.value) changes.push('Mark as done')
  if (bulkDeadline.value) changes.push(`Set deadline to ${bulkDeadline.value}`)
  if (bulkStartDate.value) changes.push(`Set start date to ${bulkStartDate.value}`)
  return changes
})

function clearBulkEdit() {
  selectedIds.value = new Set()
  selectionAnchorIdx.value = null
  resetBulkFields()
}

function resetBulkFields() {
  bulkDone.value = false
  bulkDeadline.value = ''
  bulkStartDate.value = ''
}

function showBulkConfirm() {
  showConfirmModal.value = true
}

async function confirmBulkEdit() {
  const selectedArray = Array.from(selectedIds.value)
  const updates: Record<string, any> = {}

  if (bulkDone.value) {
    updates.completed = new Date().toISOString()
  }
  if (bulkDeadline.value) {
    updates.deadline = toIso(bulkDeadline.value)
  }
  if (bulkStartDate.value) {
    updates.start_date = toIso(bulkStartDate.value)
  }

  // Optimistic update: update local todos first
  for (const todoId of selectedArray) {
    const todo = props.todos.find(t => t.id === todoId)
    if (todo) {
      Object.assign(todo, updates)
    }
  }

  try {
    // Sync to DB
    await Promise.all(
      selectedArray.map(id =>
        supabase.from('todos').update(updates).eq('id', id)
      )
    )
  } catch (error) {
    emit('error', error instanceof Error ? error.message : 'Failed to update todos')
  }

  showConfirmModal.value = false
  clearBulkEdit()
}

// ── Editing ─────────────────────────────────────────────────────────────────

const editingId = ref<number | null>(null)
const editDescription = ref('')
const editingDateKey = ref<string | null>(null)
const addingLabelForTodo = ref<number | null>(null)
const newLabelInput = ref('')
const labelInputRef = ref<HTMLInputElement | HTMLInputElement[] | null>(null)
const cachedLabels = ref<Label[]>([])


async function toggleCompleted(todo: Todo) {
  const completed = todo.completed ? null : new Date().toISOString()
  const { error } = await supabase.from('todos').update({ completed }).eq('id', todo.id)
  if (error) emit('error', error.message)
  else todo.completed = completed
}

function startEdit(todo: Todo) {
  editingId.value = todo.id
  editDescription.value = todo.description
}

async function saveEdit(todo: Todo) {
  if (editingId.value !== todo.id) return
  const description = editDescription.value.trim()
  if (!description) { editingId.value = null; return }
  const { error } = await supabase.from('todos').update({ description }).eq('id', todo.id)
  if (error) emit('error', error.message)
  else { todo.description = description; editingId.value = null }
}

function onDateBlur(todo: Todo, field: 'start_date' | 'deadline', e: FocusEvent) {
  if (editingDateKey.value === null) return
  commitDate(todo, field, (e.target as HTMLInputElement).value)
}

async function commitDate(todo: Todo, field: 'start_date' | 'deadline', value: string) {
  editingDateKey.value = null
  const iso = toIso(value)
  const { error } = await supabase.from('todos').update({ [field]: iso }).eq('id', todo.id)
  if (error) emit('error', error.message)
  else todo[field] = iso
}

async function deleteTodo(id: number) {
  const { error } = await supabase.from('todos').delete().eq('id', id)
  if (error) emit('error', error.message)
  else emit('delete', id)
}

async function onLabelInputChange() {
  const currentValue = newLabelInput.value

  // Auto-complete against cached labels
  const match = findLabelMatch(currentValue, cachedLabels.value)
  if (match && match.name !== currentValue) {
    // Auto-fill with the matched label
    newLabelInput.value = match.name

    // Select the auto-filled portion so it can be overwritten
    await nextTick()
    const inputEl = Array.isArray(labelInputRef.value) ? labelInputRef.value[0] : labelInputRef.value
    if (inputEl) {
      applyLabelSelection(inputEl, currentValue.trim().length, match.name.length)
    }
  }
}

async function addLabelToTodo(todo: Todo) {
  const labelName = newLabelInput.value.trim()
  if (!labelName) {
    addingLabelForTodo.value = null
    return
  }

  // Check if label already exists locally
  let label = todo.todo_labels?.find(item => item.labels.name.toLowerCase() === labelName.toLowerCase())?.labels
  if (label) {
    addingLabelForTodo.value = null
    newLabelInput.value = ''
    return
  }

  try {
    const newLabel = await findOrCreateLabel(labelName)
    await insertTodoLabels(todo.id, [newLabel])

    // Update the todo's labels locally
    if (!todo.todo_labels) {
      todo.todo_labels = []
    }
    todo.todo_labels.push({ labels: newLabel })
  } catch (error) {
    emit('error', error instanceof Error ? error.message : 'Failed to add label')
  }

  addingLabelForTodo.value = null
  newLabelInput.value = ''
}

async function removeLabelFromTodo(todo: Todo, labelId: number) {
  try {
    await removeTodoLabel(todo.id, labelId)

    // Remove from local UI
    if (todo.todo_labels) {
      todo.todo_labels = todo.todo_labels.filter(item => item.labels.id !== labelId)
    }
  } catch (error) {
    emit('error', error instanceof Error ? error.message : 'Failed to remove label')
  }
}

// ── Drag-and-drop ────────────────────────────────────────────────────────────
const draggingId = ref<number | null>(null)
const dropBeforeId = ref<number | 'end' | null>(null)

const draggingIds = computed<number[]>(() => {
  if (draggingId.value === null) return []
  if (selectedIds.value.has(draggingId.value))
    return sortedTodos.value.filter(t => selectedIds.value.has(t.id)).map(t => t.id)
  return [draggingId.value]
})

async function ensurePriorities() {
  if (!props.todos.some(t => t.priority === null)) return
  const updates = sortedTodos.value.map((t, i) => ({ id: t.id, priority: (i + 1) * PRIORITY_STEP }))
  await Promise.all(updates.map(({ id, priority }) => supabase.from('todos').update({ priority }).eq('id', id)))
  for (const { id, priority } of updates) {
    const t = props.todos.find(t => t.id === id)
    if (t) t.priority = priority
  }
}

async function rebalancePriorities() {
  const updates = sortedTodos.value.map((t, i) => ({ id: t.id, priority: (i + 1) * PRIORITY_STEP }))
  await Promise.all(updates.map(({ id, priority }) => supabase.from('todos').update({ priority }).eq('id', id)))
  for (const { id, priority } of updates) {
    const t = props.todos.find(t => t.id === id)
    if (t) t.priority = priority
  }
}

function calcNewPriorities(ids: number[], targetBeforeId: number | 'end'): number[] | null {
  const rest = sortedTodos.value.filter(t => !ids.includes(t.id))
  let prevP: number, nextP: number | null
  if (targetBeforeId === 'end') {
    prevP = rest[rest.length - 1]?.priority ?? 0
    nextP = null
  } else {
    const idx = rest.findIndex(t => t.id === targetBeforeId)
    if (idx === -1) return null
    prevP = rest[idx - 1]?.priority ?? 0
    nextP = rest[idx]?.priority ?? null
  }
  const n = ids.length
  if (nextP === null) return Array.from({ length: n }, (_, i) => prevP + PRIORITY_STEP * (i + 1))
  if (nextP - prevP <= n) return null
  const step = Math.floor((nextP - prevP) / (n + 1))
  return Array.from({ length: n }, (_, i) => prevP + step * (i + 1))
}

async function onDragStart(todo: Todo, e: DragEvent) {
  if (!selectedIds.value.has(todo.id)) {
    selectedIds.value = new Set([todo.id])
    selectionAnchorIdx.value = sortedTodos.value.findIndex(t => t.id === todo.id)
  }
  draggingId.value = todo.id
  e.dataTransfer!.effectAllowed = 'move'
  await ensurePriorities()
}

function compareByActiveCriteria(a: Todo, b: Todo): number {
  for (const { key, dir } of sortCriteria.value) {
    const mul = dir === 'asc' ? 1 : -1
    const av = a[key] ?? null
    const bv = b[key] ?? null
    if (av === bv) continue
    if (av === null) return mul
    if (bv === null) return -mul
    if (av < bv) return -mul
    if (av > bv) return mul
  }
  return 0
}

function isValidDropPosition(targetBeforeId: number | 'end'): boolean {
  const ids = draggingIds.value
  if (!ids.length || !sortCriteria.value.length) return true
  const rest = sortedTodos.value.filter(t => !ids.includes(t.id))
  const insertIdx = targetBeforeId === 'end' ? rest.length : rest.findIndex(t => t.id === targetBeforeId)
  if (insertIdx === -1) return false
  return ids.every(id => {
    const dragged = props.todos.find(t => t.id === id)
    if (!dragged) return false
    for (let j = 0; j < insertIdx; j++) {
      if (rest[j] && compareByActiveCriteria(rest[j]!, dragged) > 0) return false
    }
    for (let j = insertIdx; j < rest.length; j++) {
      if (rest[j] && compareByActiveCriteria(dragged, rest[j]!) > 0) return false
    }
    return true
  })
}

function onDragOver(todo: Todo, e: DragEvent) {
  e.preventDefault()
  e.dataTransfer!.dropEffect = 'move'
  const row = e.currentTarget as HTMLElement
  const midY = row.getBoundingClientRect().top + row.getBoundingClientRect().height / 2
  let candidate: number | 'end'
  if (e.clientY < midY) {
    candidate = todo.id
  } else {
    const list = sortedTodos.value
    const idx = list.findIndex(t => t.id === todo.id)
    const next = list[idx + 1]
    candidate = next ? next.id : 'end'
  }
  dropBeforeId.value = draggingIds.value.length > 0 && isValidDropPosition(candidate) ? candidate : null
}

function onDragLeave(e: DragEvent) {
  if (!(e.currentTarget as HTMLElement).contains(e.relatedTarget as Node)) {
    dropBeforeId.value = null
  }
}

async function onDrop(e: DragEvent) {
  e.preventDefault()
  const ids = draggingIds.value
  const beforeId = dropBeforeId.value
  draggingId.value = null
  dropBeforeId.value = null
  if (!ids.length || beforeId === null) return
  if (typeof beforeId === 'number' && ids.includes(beforeId)) return
  let priorities = calcNewPriorities(ids, beforeId)
  if (priorities === null) {
    await rebalancePriorities()
    priorities = calcNewPriorities(ids, beforeId)
    if (priorities === null) return
  }
  for (let i = 0; i < ids.length; i++) {
    const t = props.todos.find(t => t.id === ids[i])
    if (t) t.priority = priorities![i] as number
  }
  Promise.all(ids.map((id, i) => supabase.from('todos').update({ priority: priorities![i] }).eq('id', id)))
}

function onDragEnd() {
  draggingId.value = null
  dropBeforeId.value = null
}

// ── Lifecycle ────────────────────────────────────────────────────────────────

onMounted(async () => {
  document.addEventListener('click', onDocumentClick)
  try {
    cachedLabels.value = await fetchAllLabels()
  } catch (error) {
    console.error('Failed to fetch labels:', error)
  }
})
onUnmounted(() => document.removeEventListener('click', onDocumentClick))
</script>

<style scoped>
.sort-bar {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.sort-label {
  font-size: 0.85rem;
  color: #a8a095;
  white-space: nowrap;
}

.sort-criteria {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-wrap: wrap;
}

.sort-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.2rem;
  background: #1d1f20;
  border: 1px solid #021975;
  border-radius: 4px;
  padding: 0.15rem 0.4rem;
  font-size: 0.85rem;
}

.sort-chip-label { color: #7697D7; }

.sort-chip-dir,
.sort-chip-remove {
  background: none;
  border: none;
  cursor: pointer;
  padding: 0 0.1rem;
  font-size: 0.85rem;
  line-height: 1;
  color: #6398f1;
}

.sort-chip-remove { color: #a5b4fc; font-size: 1rem; }
.sort-chip-dir:hover { color: #3730a3; }
.sort-chip-remove:hover { color: #e74c3c; }

.sort-add-select {
  font-size: 0.85rem;
  padding: 0.15rem 0.3rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  background: #fff;
  cursor: pointer;
  color: #555;
}

.filter-bar {
  display: flex;
  gap: 1.25rem;
  margin-bottom: 0.75rem;
}

.filter-label {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.875rem;
  color: #b2aca2;
  cursor: pointer;
  user-select: none;
}

.loading { color: #888; }

.table-scroll {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.todo-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.95rem;
}

.todo-table th,
.todo-table td {
  padding: 0.5rem 0.6rem;
  border-bottom: 1px solid #393d40;
  text-align: left;
  vertical-align: middle;
  white-space: nowrap;
}

.todo-table thead th {
  font-weight: 600;
  color: #bdb7af;
  background: #1e2021;
}

.todo-table tr.selected td { background: #212325; }

.todo-table tr.completed td span {
  text-decoration: line-through;
  color: #999;
}

.todo-table tr.dragging { opacity: 0.35; }
.todo-table tr.drop-before { border-top: 2px solid #4f8ef7; }
.todo-table tr.drop-sentinel { height: 8px; }
.todo-table tbody tr[draggable] { cursor: grab; }
.todo-table tbody tr[draggable]:active { cursor: grabbing; }

.col-done { width: 2rem; text-align: center; }
.col-description { width: 100%; max-width: 0; min-width: 14rem; }
.todo-table .col-description { white-space: normal; word-break: break-word; }
.col-date { width: 10rem; }
.col-actions { width: 5rem; text-align: right; }

.checkbox { width: 1.1rem; height: 1.1rem; cursor: pointer; }

.description-cell {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  flex-wrap: wrap;
}

.description-text { cursor: text; }

.labels-container {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.label-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  background: #1a3a52;
  color: #6fa3d1;
  padding: 0.2rem 0.5rem;
  border-radius: 3px;
  font-size: 0.8rem;
  white-space: nowrap;
  border: 1px solid #2a5080;
}

.label-badge-remove {
  background: none;
  border: none;
  cursor: pointer;
  color: #6fa3d1;
  font-size: 1rem;
  padding: 0;
  line-height: 1;
  font-family: inherit;
  opacity: 0.6;
  transition: opacity 0.2s;
}

.label-badge-remove:hover {
  opacity: 1;
  color: #e74c3c;
}

.labels-and-add {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-wrap: wrap;
}

.label-add-btn {
  background: none;
  border: none;
  cursor: pointer;
  color: #6a6562;
  font-size: 0.9rem;
  padding: 0.2rem 0.4rem;
  line-height: 1;
  font-family: inherit;
  opacity: 0;
  transition: opacity 0.2s, color 0.2s;
}

.description-cell:hover .label-add-btn {
  opacity: 1;
}

.label-add-btn:hover {
  color: #a8a095;
}

.label-input-wrapper {
  position: relative;
  display: inline-block;
}

.label-badge-input {
  position: absolute;
  top: 0;
  left: 0;
  background: #1a3a52;
  color: #6fa3d1;
  padding: 0.25rem 0.4rem;
  border-radius: 3px;
  font-size: 0.8rem;
  border: 1px solid #2a5080;
  font-family: inherit;
  width: 100%;
  box-sizing: border-box;
}

.label-badge-input::placeholder {
  color: #4a6a82;
}

.label-input-shadow {
  display: inline-block;
  visibility: hidden;
  white-space: nowrap;
  pointer-events: none;
  padding: 0.25rem 0.4rem;
  font-size: 0.8rem;
  border-radius: 3px;
  font-family: inherit;
  min-width: 80px;
}

.input {
  padding: 0.4rem 0.6rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 0.95rem;
}

.input.inline { flex: 1; }

.date-input {
  font-size: 0.85rem;
  padding: 0.2rem 0.4rem;
  width: 100%;
  box-sizing: border-box;
}

.date-value { cursor: pointer; font-size: 0.9rem; }
.date-value:hover { text-decoration: underline; }

.date-add-btn {
  background: none;
  border: none;
  cursor: pointer;
  color: #aaa;
  font-size: 0.85rem;
  padding: 0;
  line-height: 1;
  font-family: inherit;
}

.date-add-btn:hover { color: #555; }

.btn {
  padding: 0.4rem 0.9rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.95rem;
}

.btn-danger { background: #a22114; color: #fff; }
.btn-primary { background: #0066cc; color: #fff; }
.btn-secondary { background: #555; color: #fff; }

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.sticky-bulk-bar {
  position: sticky;
  bottom: 0;
  background: #1e2021;
  border-top: 2px solid #393d40;
  padding: 0.75rem 0.6rem;
  z-index: 10;
  box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.3);
}

.bulk-bar-content {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  flex-wrap: wrap;
}

.bulk-bar-info {
  font-size: 0.9rem;
  color: #bdb7af;
  min-width: 120px;
}

.bulk-bar-fields {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  flex-wrap: wrap;
  flex: 1;
}

.bulk-field {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9rem;
  color: #bdb7af;
  cursor: pointer;
  user-select: none;
}

.bulk-label {
  white-space: nowrap;
}

.bulk-date-input {
  padding: 0.4rem;
  border: 1px solid #555;
  border-radius: 3px;
  background: #2a2d30;
  color: #bdb7af;
  font-size: 0.9rem;
  width: 120px;
}

.bulk-date-input::placeholder {
  color: #666;
}

.bulk-bar-actions {
  display: flex;
  gap: 0.5rem;
  white-space: nowrap;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: #1e2021;
  border: 1px solid #393d40;
  border-radius: 8px;
  padding: 1.5rem;
  max-width: 500px;
  width: 90%;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
}

.modal-title {
  margin: 0 0 1rem 0;
  font-size: 1.25rem;
  color: #bdb7af;
}

.modal-text {
  margin: 0 0 0.75rem 0;
  color: #b2aca2;
  font-size: 0.95rem;
}

.modal-changes {
  list-style: none;
  padding: 0.75rem 0;
  margin: 0 0 1rem 0;
  background: #2a2d30;
  border-left: 3px solid #0066cc;
  padding-left: 1rem;
}

.modal-changes li {
  color: #8b8580;
  font-size: 0.9rem;
  margin: 0.4rem 0;
  font-family: monospace;
}

.modal-warning {
  margin: 0 0 1.5rem 0;
  color: #e74c3c;
  font-size: 0.85rem;
  font-weight: 500;
}

.modal-actions {
  display: flex;
  gap: 0.75rem;
  justify-content: flex-end;
}
</style>
