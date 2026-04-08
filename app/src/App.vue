<template>
  <header class="app-header">
    <div class="header-inner">
      <h1>Taskmount</h1>
      <button v-if="session" class="btn btn-secondary sign-out-btn" @click="signOut">Sign out</button>
    </div>
  </header>

  <AuthScreen v-if="!session" />

  <main v-else class="app-content">
    <AddTodoPanel
      :todos="todos"
      @add="todos.unshift($event)"
      @add-commit="onAddCommit"
      @add-rollback="onAddRollback"
      @imported="todos.push(...$event)"
    />

    <p v-if="error" class="error">{{ error }}</p>

    <TodoTable
      :todos="todos"
      :loading="loading"
      @delete="todos = todos.filter(t => t.id !== $event)"
      @error="error = $event"
    />
  </main>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase, type Todo } from './supabase'
import type { Session } from '@supabase/supabase-js'
import { fetchTodos as fetchTodosFromService } from './services/todoService'
import AuthScreen from './components/AuthScreen.vue'
import AddTodoPanel from './components/AddTodoPanel.vue'
import TodoTable from './components/TodoTable.vue'

// ── Auth ────────────────────────────────────────────────────────────────────

const session = ref<Session | null>(null)

async function signOut() {
  await supabase.auth.signOut()
  todos.value = []
}

// ── Todos ───────────────────────────────────────────────────────────────────

const todos = ref<Todo[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

function onAddCommit(tempId: number, todo: Todo) {
  const idx = todos.value.findIndex(t => t.id === tempId)
  if (idx !== -1) todos.value.splice(idx, 1, todo)
}

function onAddRollback(tempId: number, message: string) {
  const idx = todos.value.findIndex(t => t.id === tempId)
  if (idx !== -1) todos.value.splice(idx, 1)
  error.value = message
}

async function fetchTodos() {
  loading.value = true
  error.value = null
  try {
    todos.value = await fetchTodosFromService()
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown error'
  } finally {
    loading.value = false
  }
}

// ── Lifecycle ────────────────────────────────────────────────────────────────

onMounted(async () => {
  const { data: { session: initial } } = await supabase.auth.getSession()
  session.value = initial
  if (initial) fetchTodos()

  supabase.auth.onAuthStateChange((_, newSession) => {
    const wasSignedIn = session.value !== null
    session.value = newSession
    if (newSession && !wasSignedIn) fetchTodos()
  })
})
</script>

<style scoped>
.app-header {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  background: #181A1B;
  border-bottom: 1px solid #393d40;
  z-index: 50;
  font-family: sans-serif;
}

.header-inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  max-width: 960px;
  margin: 0 auto;
  padding: 0.75rem 1rem;
}

.header-inner h1 {
  margin: 0;
  font-size: 1.25rem;
}

.app-content {
  max-width: 960px;
  margin: 0 auto;
  padding: 5rem 1rem 2rem;
  font-family: sans-serif;
}

.btn {
  padding: 0.4rem 0.9rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.95rem;
}

.btn-secondary {
  background: #2a2d2f;
  color: #c8c3bc;
}

.sign-out-btn {
  font-size: 0.85rem;
  padding: 0.3rem 0.7rem;
}

.error {
  color: #e74c3c;
  margin-bottom: 1rem;
}
</style>
