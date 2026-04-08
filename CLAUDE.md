# Taskmount Project Context

## Overview
A Vue 3 todo app with Supabase backend. Todos can have labels, start dates, deadlines, and priorities. UI features drag-to-reorder, label management, and search/filter.

## Architecture: Strict Separation of Concerns

### Three Layers (No Cross-Contamination)

**1. Database & Business Logic** (`app/src/services/`, `app/src/utils/`)
- Pure functions with **zero Vue imports**
- All Supabase calls here
- Can be tested, replaced, or reused independently

**2. Components** (`app/src/components/`)
- Vue only—no direct Supabase calls
- Import and call service functions
- Manage reactive state (refs for form inputs, UI state)
- Pass data via props, communicate via emits

**3. Shared Types & Client** (`app/src/supabase.ts`)
- Exports: `supabase` client, `Todo` type, `Label` type
- Single source of truth

### File Structure
```
app/src/
├── components/           # Vue components only
│   ├── AddTodoPanel.vue # Add todo form + label management
│   ├── TodoTable.vue    # Todo display, edit, drag-to-reorder, label mgmt
│   ├── AuthScreen.vue
│   └── App.vue          # Root, fetches todos, auth state
├── services/             # Database operations (no Vue)
│   └── todoService.ts   # All Supabase calls
├── utils/                # Pure calculations
│   ├── dates.ts         # toDateOnly, toRelativeDate, toIso
│   └── priority.ts      # PRIORITY_STEP, computeNextPriority
└── supabase.ts          # Types + client init
```

## Key Patterns

### Optimistic Updates (Instant UI Feedback)
User actions update local state **immediately**, then sync to database in background.

**Working Examples**:
- Drag-to-reorder todos: updates `priority` instantly, then sends batch updates
- Toggle completed: flips `todo.completed` instantly, then syncs

**Not Working Yet (Labels)**:
- Add label: waits for `findOrCreateLabel()` before showing
- Remove label: waits for DB delete before removing from UI

**Fix Pattern** (do this for labels):
```ts
// 1. Update immediately
if (!todo.todo_labels) todo.todo_labels = []
todo.todo_labels.push({ labels: newLabel })

// 2. Sync to DB in background
try {
  await insertTodoLabels(todo.id, [newLabel])
} catch (error) {
  // Rollback if needed
  todo.todo_labels.pop()
}
```

## Service Layer (`app/src/services/todoService.ts`)

All async, throwable functions—no Supabase error objects, throw on error.

```ts
fetchTodos(): Promise<Todo[]>                              // select * + labels join
insertTodo(description, start_date, deadline, priority): Promise<Todo>
insertTodoLabels(todoId, labels): Promise<void>           // batch insert to todo_labels
findOrCreateLabel(labelName): Promise<Label>              // case-insensitive lookup or create
bulkInsertTodos(rows): Promise<Todo[]>                    // batch insert todos
removeTodoLabel(todoId, labelId): Promise<void>           // delete assoc + cleanup label if unused
```

## Utils

**`app/src/utils/priority.ts`**:
- `PRIORITY_STEP = 65536` — constant imported by AddTodoPanel and TodoTable
- `computeNextPriority(todos)` — returns priority for new todo (min priority - PRIORITY_STEP)
- `computeImportPriorities(todos, count)` — array of priorities for bulk import

**`app/src/utils/dates.ts`**:
- `toDateOnly(iso)` → "2026-04-08"
- `toRelativeDate(iso)` → "Today", "Tomorrow", "5 days away"
- `toIso(dateString)` → ISO timestamp

## Type Definitions (`app/src/supabase.ts`)

```ts
type Label = { id: number; name: string }

type Todo = {
  id: number
  description: string
  completed: string | null        // ISO timestamp or null
  start_date: string | null       // ISO timestamp
  deadline: string | null         // ISO timestamp
  priority: number | null
  todo_labels: Array<{ labels: Label }>  // nested from Supabase join
}
```

## Supabase Patterns

**Nested join** (get todos with labels):
```ts
supabase.from('todos').select('*, todo_labels(labels(id, name))').order('id')
```

**Case-insensitive lookup**:
```ts
supabase.from('labels').select('id, name').ilike('name', labelName).single()
```

**Count without data** (check if label is used):
```ts
supabase.from('todo_labels').select('*', { count: 'exact', head: true }).eq('label_id', id)
```

## Component Patterns

**AddTodoPanel.vue**: Form to add todos + labels
- State: `newDescription`, `newStartDate`, `newDeadline`, `newLabels`, `addingLabel`, `newLabelInput`
- Calls: `insertTodo()`, `insertTodoLabels()`, `findOrCreateLabel()`, `bulkInsertTodos()`
- Emits: `@add` (optimistic), `@add-commit` (confirmed), `@add-rollback` (error), `@imported`

**TodoTable.vue**: Display, edit, drag-to-reorder, labels
- Row is draggable for reordering (updates priority)
- Double-click description to edit
- Click dates to edit
- Labels show with remove (×) button
- Plus button to add labels to existing todo
- Drag-and-drop uses priority-based reordering (PRIORITY_STEP increments)

**App.vue**: Root component
- Fetches todos on auth state change
- Manages session state
- Orchestrates optimistic add/rollback via `@add-commit` and `@add-rollback` emits

## How to Extend

**Add new database operation**:
1. Add function to `todoService.ts` (pure function, throw on error)
2. Import in component, call in try/catch

**Add new UI feature**:
1. Add local state with `ref()` in component
2. Call service functions in event handlers
3. Update local state immediately (optimistic), then sync to DB

**Add calculation logic**:
1. Create function in `utils/` (pure, no Vue)
2. Export and import where needed

**Add constant**:
1. Export from `utils/` if used in multiple places
2. Component-local if only one component needs it

## Key Decisions

- **No store (Vuex/Pinia)**: Props/emits sufficient for this data flow
- **Optimistic updates**: For perceived responsiveness
- **Service layer**: Keep DB logic separate for testability and reusability
- **No local caching**: Fetch on auth state change, use in-memory state
- **Drag-to-reorder via priority**: Not position-based, allows concurrent edits

## Known Issues / TODO

- Labels don't use optimistic updates (should fix: update UI before DB call)
- No optimistic updates for edit/delete operations in TodoTable
- No undo/rollback UI for failed operations

