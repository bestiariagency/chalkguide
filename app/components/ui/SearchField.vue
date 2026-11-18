<script setup lang="ts">
import { Search, X } from 'lucide-vue-next'

/**
 * Search field (design system "UiSearchField"): visible label, magnifier, clear button and the
 * `/` hint (fine pointer + empty field). `/` focuses it unless you are already typing in a
 * field; Esc clears and, when already empty, leaves the field. No submit: it filters as you type.
 */
const props = withDefaults(
  defineProps<{
    label: string
    clearLabel: string
    placeholder?: string
    /** Enables the global `/` shortcut (one field per page). */
    shortcut?: boolean
    /** Keeps the label for assistive tech only. */
    hideLabel?: boolean
  }>(),
  { placeholder: undefined, shortcut: false, hideLabel: false },
)
const emit = defineEmits<{ shortcut: [] }>()
const model = defineModel<string>({ default: '' })
const input = ref<HTMLInputElement | null>(null)
const id = useId()

const finePointer = ref(false)
onMounted(() => {
  finePointer.value = window.matchMedia('(pointer: fine)').matches
  if (props.shortcut) window.addEventListener('keydown', onShortcut)
})
onBeforeUnmount(() => window.removeEventListener('keydown', onShortcut))

async function onShortcut(event: KeyboardEvent) {
  if (event.key !== '/' || event.ctrlKey || event.metaKey || event.altKey) return
  const target = event.target as HTMLElement | null
  if (target?.closest('input, textarea, select, [contenteditable]')) return
  event.preventDefault()
  emit('shortcut')
  await nextTick()
  input.value?.focus()
}

function onEscape() {
  if (model.value) model.value = ''
  else input.value?.blur()
}
function clear() {
  model.value = ''
  input.value?.focus()
}
defineExpose({ focus: () => input.value?.focus() })
</script>

<template>
  <form role="search" class="min-w-0" @submit.prevent>
    <label :for="id" :class="hideLabel ? 'sr-only' : 'label-mini mb-2 block'">{{ label }}</label>
    <div class="relative">
      <Search
        :size="18"
        aria-hidden="true"
        class="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-meta"
      />
      <input
        :id="id"
        ref="input"
        v-model="model"
        type="search"
        enterkeyhint="search"
        autocomplete="off"
        autocapitalize="off"
        spellcheck="false"
        :placeholder="placeholder"
        :aria-keyshortcuts="shortcut ? '/' : undefined"
        :class="[
          fieldClasses,
          model ? 'pe-11' : 'pe-10',
          'ps-11 text-ellipsis [&::-webkit-search-cancel-button]:hidden [&::-webkit-search-decoration]:hidden',
        ]"
        @keydown.esc.prevent="onEscape"
      />
      <button
        v-if="model"
        type="button"
        class="absolute top-1/2 right-0 grid size-11 -translate-y-1/2 place-items-center rounded-md text-meta hover:text-foreground"
        :aria-label="clearLabel"
        @click="clear"
      >
        <X :size="18" aria-hidden="true" />
      </button>
      <kbd
        v-else-if="shortcut && finePointer"
        class="pointer-events-none absolute top-1/2 right-3 -translate-y-1/2 rounded-sm border border-control px-1.5 py-0.5 font-mono text-note leading-none text-meta"
        aria-hidden="true"
      >
        /
      </kbd>
    </div>
  </form>
</template>
