<template>
  <div class="tab-container">
    <div class="tab-bar">
      <button class="tab-btn" :class="{ active: activeTab === 'add' }" @click="activeTab = 'add'">Add todo</button>
      <button class="tab-btn" :class="{ active: activeTab === 'import' }" @click="activeTab = 'import'">Add list</button>
    </div>

    <div class="tab-panel">
      <form v-if="activeTab === 'add'" class="add-form" @submit.prevent="addTodo">
        <div class="description-row">
          <input
            v-model="newDescription"
            placeholder="New todo description"
            required
            class="input description-input"
          />
        </div>
        <div class="labels-section">
          <span v-for="(labelName, index) in newLabelNames" :key="`label-${index}`" class="label-badge">
            {{ labelName }}
            <button type="button" class="label-badge-remove" @click="removeLabel(index)">×</button>
          </span>
          <div v-for="(inputValue, index) in newLabelInputs" :key="`input-${index}`" class="label-input-wrapper">
            <input
              :ref="el => registerLabelInput(index, el)"
              v-model="newLabelInputs[index]"
              type="text"
              :placeholder="index === 0 ? 'Add label...' : 'Add another label...'"
              class="label-badge-input"
              @input="onLabelInput(index)"
              @keydown.enter.prevent="addLabel(index)"
              @keydown.tab.prevent="focusNext(index)"
              @keyup.escape="clearLabelInput(index)"
              @blur="onLabelBlur(index)"
            />
            <span class="label-input-shadow">{{ newLabelInputs[index] }}w</span>
          </div>
        </div>
        <div class="add-form-bottom">
          <label class="form-date-label">
            Start date
            <input v-model="newStartDate" type="date" class="input" />
          </label>
          <label class="form-date-label">
            Deadline
            <input v-model="newDeadline" type="date" class="input" />
          </label>
          <button type="submit" class="btn btn-primary add-btn">Add</button>
        </div>
      </form>

      <div v-if="activeTab === 'import'" class="import-form">
        <p class="import-hint">Paste one todo per line.</p>
        <textarea
          v-model="importText"
          class="import-textarea"
          placeholder="Buy milk&#10;Walk the dog&#10;Write tests"
        />
        <p v-if="importError" class="error">{{ importError }}</p>
        <button class="btn btn-primary import-btn" :disabled="importing" @click="importTodos">
          {{ importing ? 'Importing…' : 'Add todos' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, nextTick, onMounted } from 'vue'
import type { Todo, Label } from '../supabase'
import { toIso } from '../utils/dates'
import { computeNextPriority, computeImportPriorities } from '../utils/priority'
import { insertTodo, insertTodoLabels, findOrCreateLabel, bulkInsertTodos, fetchAllLabels } from '../services/todoService'
import { findLabelMatch, applyLabelSelection } from '../utils/labelAutocomplete'

const props = defineProps<{ todos: Todo[] }>()

const emit = defineEmits<{
  add: [todo: Todo]
  'add-commit': [tempId: number, todo: Todo]
  'add-rollback': [tempId: number, message: string]
  imported: [todos: Todo[]]
}>()

const activeTab = ref<'add' | 'import'>('add')
const newDescription = ref('')
const newStartDate = ref('')
const newDeadline = ref('')
const importText = ref('')
const importError = ref<string | null>(null)
const importing = ref(false)
const newLabelNames = ref<string[]>([])
const newLabelInputs = ref<string[]>([''])
const labelInputRefs = ref<HTMLInputElement[]>([])
const cachedLabels = ref<Label[]>([])

function registerLabelInput(index: number, el: any) {
  if (el) {
    labelInputRefs.value[index] = el as HTMLInputElement
  }
}

onMounted(async () => {
  try {
    cachedLabels.value = await fetchAllLabels()
  } catch (error) {
    console.error('Failed to fetch labels:', error)
  }
})


async function addTodo() {
  const priority = computeNextPriority(props.todos)

  // Collect all label names (both confirmed and in input fields)
  const allLabelNames = [
    ...newLabelNames.value,
    ...newLabelInputs.value.map(input => input.trim()).filter(Boolean),
  ]

  // Get label objects with real IDs from the database
  let labels: Label[] = []
  try {
    labels = await Promise.all(
      allLabelNames.map(name => findOrCreateLabel(name))
    )
  } catch (error) {
    emit('add-rollback', 0, error instanceof Error ? error.message : 'Failed to add labels')
    return
  }

  const tempId = -Date.now()
  const optimistic: Todo = {
    id: tempId,
    description: newDescription.value,
    start_date: toIso(newStartDate.value),
    deadline: toIso(newDeadline.value),
    completed: null,
    priority,
    todo_labels: labels.map(l => ({ labels: l })),
  }
  emit('add', optimistic)
  newDescription.value = ''
  newStartDate.value = ''
  newDeadline.value = ''
  newLabelInputs.value = ['']
  newLabelNames.value = []

  try {
    const data = await insertTodo(
      optimistic.description,
      optimistic.start_date,
      optimistic.deadline,
      priority
    )

    // Insert label associations
    if (labels.length > 0) {
      await insertTodoLabels(data.id, labels)
    }

    emit('add-commit', tempId, { ...data, todo_labels: labels.map(l => ({ labels: l })) } as Todo)
  } catch (error) {
    emit('add-rollback', tempId, error instanceof Error ? error.message : 'Unknown error')
  }
}

async function onLabelInput(index: number) {
  const currentValue = newLabelInputs.value[index]!

  // Auto-complete against cached labels
  const match = findLabelMatch(currentValue, cachedLabels.value)
  if (match && match.name !== currentValue) {
    // Auto-fill with the matched label
    newLabelInputs.value[index] = match.name

    // Select the auto-filled portion so it can be overwritten
    await nextTick()
    const inputEl = labelInputRefs.value[index]
    if (inputEl) {
      applyLabelSelection(inputEl, currentValue.trim().length, match.name.length)
    }
  }

  // Ensure there's always an empty input after the last non-empty one
  if (index === newLabelInputs.value.length - 1 && currentValue.trim()) {
    newLabelInputs.value.push('')
  }
}

async function addLabel(index: number) {
  const labelName = newLabelInputs.value[index]!.trim()
  if (!labelName) {
    return
  }

  // Check if label already exists locally (case-insensitive)
  if (newLabelNames.value.some(n => n.toLowerCase() === labelName.toLowerCase())) {
    newLabelInputs.value[index] = ''
    return
  }

  // Add to completed labels
  newLabelNames.value.push(labelName)
  newLabelInputs.value[index] = ''

  // Focus the same input for the next label
  await nextTick()
  labelInputRefs.value[index]?.focus()
}

function focusNext(index: number) {
  // Focus next input, or add a new one if we're at the end
  if (index === newLabelInputs.value.length - 1) {
    newLabelInputs.value.push('')
  }
  nextTick(() => {
    labelInputRefs.value[index + 1]?.focus()
  })
}

function clearLabelInput(index: number) {
  newLabelInputs.value[index] = ''
}

function onLabelBlur(index: number) {
  // If it's an empty input and not the last one, remove it
  if (!newLabelInputs.value[index]!.trim() && index < newLabelInputs.value.length - 1) {
    newLabelInputs.value.splice(index, 1)
  }
}

function removeLabel(index: number) {
  newLabelNames.value.splice(index, 1)
}

async function importTodos() {
  const lines = importText.value.split('\n').map((l) => l.trim()).filter(Boolean)
  if (!lines.length) {
    importError.value = 'Paste at least one line.'
    return
  }
  importing.value = true
  importError.value = null

  try {
    const priorities = computeImportPriorities(props.todos, lines.length)
    const rows = lines.map((description, i) => ({ description, priority: priorities[i]! }))
    const todos = await bulkInsertTodos(rows)
    emit('imported', todos)
    importText.value = ''
    activeTab.value = 'add'
  } catch (error) {
    importError.value = error instanceof Error ? error.message : 'Unknown error'
  } finally {
    importing.value = false
  }
}
</script>

<style scoped>
.tab-container {
  margin-bottom: 1.5rem;
}

.tab-bar {
  display: flex;
  border-bottom: 2px solid #021975;
}

.tab-btn {
  padding: 0.4rem 1rem;
  border: none;
  background: none;
  cursor: pointer;
  font-size: 0.95rem;
  color: #a8a095;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
}

.tab-btn.active {
  color: #7697d7;
  border-bottom-color: #322c94;
  font-weight: 600;
}

.tab-panel {
  background: #1b1d1e;
  border: 1px solid #021975;
  border-top: none;
  border-radius: 0 0 6px 6px;
  padding: 0.75rem;
}

.add-form {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.description-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.description-input {
  flex: 1;
  color: #a8a09d;
}

.labels-section {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  align-items: center;
}

.label-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  background: #1a3a52;
  color: #6fa3d1;
  padding: 0.25rem 0.6rem;
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

.add-form-bottom {
  display: flex;
  align-items: flex-end;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.add-btn {
  /* align-self: flex-end; */
}

.form-date-label {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  font-size: 0.78rem;
  color: #a8a095;
}

.import-form {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.import-hint {
  margin: 0;
  color: #a8a095;
  font-size: 0.9rem;
}

.import-textarea {
  width: 100%;
  height: 160px;
  padding: 0.5rem;
  border: 1px solid #3e4446;
  border-radius: 4px;
  font-size: 0.95rem;
  resize: vertical;
  box-sizing: border-box;
  /* background-color: #2b2a33; */
}

.import-textarea::placeholder {
  color: #6e6a69;
}

.import-btn {
  align-self: flex-start;
}

.input {
  padding: 0.4rem 0.6rem;
  border: 1px solid #3e4446;
  border-radius: 4px;
  font-size: 0.95rem;
  background-color: #2b2a33;
}

.btn {
  padding: 0.4rem 0.9rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.95rem;
}

.btn-primary {
  background: #073e9a;
  color: #fff;
}

.error {
  color: #e74c3c;
  margin: 0;
}
</style>
