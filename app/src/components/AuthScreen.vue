<template>
  <main class="auth-content">
    <div class="auth-box">
      <h2>{{ authMode === 'signin' ? 'Sign in' : 'Create account' }}</h2>
      <label class="auth-label">
        Email
        <input v-model="authEmail" type="email" class="input" autocomplete="email" />
      </label>
      <label class="auth-label">
        Password
        <input v-model="authPassword" type="password" class="input" autocomplete="current-password" @keyup.enter="submitAuth" />
      </label>
      <p v-if="authError" class="error">{{ authError }}</p>
      <p v-if="authConfirmation" class="auth-confirmation">{{ authConfirmation }}</p>
      <button class="btn btn-primary" :disabled="authLoading" @click="submitAuth">
        {{ authLoading ? '…' : authMode === 'signin' ? 'Sign in' : 'Create account' }}
      </button>
      <button class="btn-link" @click="authMode = authMode === 'signin' ? 'signup' : 'signin'; authError = null; authConfirmation = null">
        {{ authMode === 'signin' ? 'No account yet? Sign up' : 'Already have an account? Sign in' }}
      </button>
    </div>
  </main>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { supabase } from '../supabase'

const authMode = ref<'signin' | 'signup'>('signin')
const authEmail = ref('')
const authPassword = ref('')
const authError = ref<string | null>(null)
const authConfirmation = ref<string | null>(null)
const authLoading = ref(false)

async function submitAuth() {
  authError.value = null
  authConfirmation.value = null
  authLoading.value = true
  if (authMode.value === 'signin') {
    const { error } = await supabase.auth.signInWithPassword({ email: authEmail.value, password: authPassword.value })
    if (error) authError.value = error.message
  } else {
    const { error } = await supabase.auth.signUp({ email: authEmail.value, password: authPassword.value })
    if (error) authError.value = error.message
    else authConfirmation.value = 'Check your email for a confirmation link.'
  }
  authLoading.value = false
}
</script>

<style scoped>
.auth-content {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  font-family: sans-serif;
}

.auth-box {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  width: 100%;
  max-width: 360px;
  padding: 2rem;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  background: #fff;
}

.auth-box h2 {
  margin: 0 0 0.25rem;
}

.auth-label {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  font-size: 0.875rem;
  color: #555;
}

.input {
  padding: 0.4rem 0.6rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 0.95rem;
}

.btn {
  padding: 0.4rem 0.9rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.95rem;
}

.btn-primary {
  background: #4f8ef7;
  color: #fff;
}

.error {
  color: #e74c3c;
  margin: 0;
}

.auth-confirmation {
  color: #16a34a;
  font-size: 0.9rem;
  margin: 0;
}

.btn-link {
  background: none;
  border: none;
  padding: 0;
  cursor: pointer;
  color: #4f8ef7;
  font-size: 0.875rem;
  text-align: left;
}

.btn-link:hover {
  text-decoration: underline;
}
</style>
