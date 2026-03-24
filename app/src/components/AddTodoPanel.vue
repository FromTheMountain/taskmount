<template>
  <div class="tab-container">
    <div class="tab-bar">
      <button class="tab-btn" :class="{ active: activeTab === 'add' }" @click="activeTab = 'add'">Add todo</button>
      <button class="tab-btn" :class="{ active: activeTab === 'import' }" @click="activeTab = 'import'">Add list</button>
    </div>

    <div class="tab-panel">
      <form v-if="activeTab === 'add'" class="add-form" @submit.prevent="addTodo">
        <input
          v-model="newDescription"
          placeholder="New todo description"
          required
          class="input description-input"
        />
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
import { ref } from 'vue'
import { supabase, type Todo } from '../supabase'
import { toIso } from '../utils/dates'

const PRIORITY_STEP = 65536

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


async function addTodo() {
  const priorities = props.todos.map(t => t.priority).filter((p): p is number => p !== null)
  const priority = priorities.length > 0 ? Math.min(...priorities) - PRIORITY_STEP : PRIORITY_STEP

  const tempId = -Date.now()
  const optimistic: Todo = {
    id: tempId,
    description: newDescription.value,
    start_date: toIso(newStartDate.value),
    deadline: toIso(newDeadline.value),
    completed: null,
    priority,
  }
  emit('add', optimistic)
  newDescription.value = ''
  newStartDate.value = ''
  newDeadline.value = ''

  const { data, error } = await supabase
    .from('todos')
    .insert({
      description: optimistic.description,
      start_date: optimistic.start_date,
      deadline: optimistic.deadline,
      priority,
    })
    .select()
    .single()

  if (error) emit('add-rollback', tempId, error.message)
  else emit('add-commit', tempId, data as Todo)
}

async function importTodos() {
  const lines = importText.value.split('\n').map((l) => l.trim()).filter(Boolean)
  if (!lines.length) {
    importError.value = 'Paste at least one line.'
    return
  }
  importing.value = true
  importError.value = null
  const priorities = props.todos.map(t => t.priority).filter((p): p is number => p !== null)
  const basePriority = priorities.length > 0 ? Math.min(...priorities) : PRIORITY_STEP * (lines.length + 1)
  const { data, error } = await supabase
    .from('todos')
    .insert(lines.map((description, i) => ({ description, priority: basePriority - (lines.length - i) * PRIORITY_STEP })))
    .select()
  if (error) {
    importError.value = error.message
  } else {
    emit('imported', data as Todo[])
    importText.value = ''
    activeTab.value = 'add'
  }
  importing.value = false
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

.description-input {
  width: 100%;
  box-sizing: border-box;
  color: #a8a09d;
}

.add-form-bottom {
  display: flex;
  align-items: flex-end;
  gap: 0.5rem;
}

.add-btn {
  align-self: flex-end;
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
