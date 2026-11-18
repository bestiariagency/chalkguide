<script setup lang="ts">
import { Search, X } from 'lucide-vue-next'

/**
 * Table toolbar: debounced search (press `/` anywhere outside a field to focus it) + `filters` slot
 * (buttons/menus and active-filter chips) + `end` slot. v-model is the committed search text.
 */
const props = defineProps<{ label: string; placeholder?: string; searchable?: boolean }>()
const search = defineModel<string>('search', { default: '' })

const text = ref(search.value)
const debounced = useDebouncedValue(text, 250)
watch(debounced, (value) => value !== search.value && (search.value = value))
watch(search, (value) => (text.value = value))

const input = ref<HTMLInputElement>()
const id = `q-${useId()}`

onMounted(() => {
  if (!props.searchable) return
  const onKey = (event: KeyboardEvent) => {
    const target = event.target as HTMLElement | null
    const typing = target && (target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName))
    if (event.key === '/' && !typing && !event.metaKey && !event.ctrlKey) {
      event.preventDefault()
      input.value?.focus()
    }
  }
  window.addEventListener('keydown', onKey)
  onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
})
</script>

<template>
  <div class="flex flex-wrap items-center gap-2 border-b border-adm-line p-3">
    <div v-if="searchable" class="relative w-full sm:w-64">
      <label :for="id" class="sr-only">{{ label }}</label>
      <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted" aria-hidden="true" />
      <input
        :id="id"
        ref="input"
        v-model="text"
        type="search"
        :placeholder="placeholder ?? 'Buscar'"
        autocomplete="off"
        :class="[admInput, 'pr-8 pl-8 max-md:pr-12 [&::-webkit-search-cancel-button]:hidden']"
        @keydown.esc="text = ''"
      />
      <button v-if="text" type="button" class="absolute top-1/2 right-1 grid size-6 -translate-y-1/2 place-items-center rounded text-adm-muted hover:text-adm-fg max-md:size-11" aria-label="Borrar la búsqueda" @click="text = ''; input?.focus()">
        <X class="size-3.5" aria-hidden="true" />
      </button>
      <kbd v-else :class="[admKbd, 'pointer-events-none absolute top-1/2 right-2 -translate-y-1/2 max-md:hidden']" aria-hidden="true">/</kbd>
    </div>
    <slot name="filters" />
    <div class="ml-auto flex items-center gap-2"><slot name="end" /></div>
  </div>
</template>
