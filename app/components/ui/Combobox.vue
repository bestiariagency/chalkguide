<script setup lang="ts" generic="O extends { id: string; disabled?: boolean }">
import { Search } from 'lucide-vue-next'

/**
 * ARIA combobox + listbox (list autocomplete). The parent filters `options` from `query`.
 * Keys: Down/Up move (opening the list), Home/End jump, Enter picks, Esc closes (then clears),
 * Tab closes. Options use mousedown.prevent so the input keeps focus. Disabled options stay
 * visible (`aria-disabled`) but cannot be picked.
 */
const props = defineProps<{
  label: string
  placeholder?: string
  options: O[]
  /** Describes the field (capacity hint…): wired through aria-describedby. */
  describedBy?: string
}>()
const query = defineModel<string>('query', { default: '' })
const emit = defineEmits<{ pick: [option: O] }>()
defineSlots<{ option(props: { option: O; active: boolean }): unknown; empty(): unknown }>()

const input = ref<HTMLInputElement | null>(null)
const listbox = ref<HTMLElement | null>(null)
const uid = useId()
const listId = `${uid}-list`
const optionId = (index: number) => `${uid}-opt-${index}`

const expanded = ref(false)
let quietFocus = false
const activeIndex = ref(-1)

watch(
  () => props.options,
  () => (activeIndex.value = -1),
)
watch(query, (value) => {
  if (value) expanded.value = true
})

const firstEnabled = (from: number, step: 1 | -1) => {
  const count = props.options.length
  for (let i = 0; i < count; i++) {
    const index = (((from + i * step) % count) + count) % count
    if (!props.options[index]?.disabled) return index
  }
  return -1
}

function move(step: 1 | -1) {
  if (!props.options.length) return
  if (!expanded.value) {
    expanded.value = true
    activeIndex.value = firstEnabled(step === 1 ? 0 : props.options.length - 1, step)
  } else {
    activeIndex.value = firstEnabled(activeIndex.value < 0 ? (step === 1 ? 0 : -1) : activeIndex.value + step, step)
  }
  scrollToActive()
}
function jump(edge: 'start' | 'end') {
  if (!expanded.value || !props.options.length) return
  activeIndex.value =
    edge === 'start' ? firstEnabled(0, 1) : firstEnabled(props.options.length - 1, -1)
  scrollToActive()
}
async function scrollToActive() {
  await nextTick()
  document.getElementById(optionId(activeIndex.value))?.scrollIntoView({ block: 'nearest' })
}
function choose(option: O | undefined) {
  if (!option || option.disabled) return
  emit('pick', option)
  query.value = ''
  expanded.value = false
  activeIndex.value = -1
  // The field gets focus back (also after a dialog opened by the parent) without reopening the list.
  quietFocus = true
  input.value?.focus()
}
function onClick() {
  quietFocus = false
  expanded.value = true
}
function onFocus() {
  if (quietFocus) quietFocus = false
  else expanded.value = true
}
function onEnter(event: KeyboardEvent) {
  if (!expanded.value) return
  event.preventDefault()
  choose(props.options[activeIndex.value])
}
function onEscape(event: KeyboardEvent) {
  if (expanded.value) {
    event.preventDefault()
    expanded.value = false
    activeIndex.value = -1
  } else if (query.value) {
    event.preventDefault()
    query.value = ''
    expanded.value = false
  }
}
function onBlur() {
  expanded.value = false
  activeIndex.value = -1
}
defineExpose({ focus: () => input.value?.focus() })
</script>

<template>
  <div class="relative">
    <label :for="`${uid}-input`" class="label-mini mb-2 block">{{ label }}</label>
    <div class="relative">
      <Search
        :size="18"
        aria-hidden="true"
        class="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-meta"
      />
      <input
        :id="`${uid}-input`"
        ref="input"
        v-model="query"
        type="text"
        role="combobox"
        autocomplete="off"
        autocapitalize="off"
        spellcheck="false"
        enterkeyhint="done"
        aria-autocomplete="list"
        :aria-expanded="expanded"
        :aria-controls="listId"
        :aria-activedescendant="expanded && activeIndex >= 0 ? optionId(activeIndex) : undefined"
        :aria-describedby="describedBy"
        :placeholder="placeholder"
        :class="[fieldClasses, 'ps-11']"
        @focus="onFocus"
        @click="onClick"
        @blur="onBlur"
        @keydown.down.prevent="move(1)"
        @keydown.up.prevent="move(-1)"
        @keydown.home="jump('start')"
        @keydown.end="jump('end')"
        @keydown.enter="onEnter"
        @keydown.esc="onEscape"
        @keydown.tab="expanded = false"
      />
    </div>
    <div
      v-show="expanded"
      class="absolute inset-x-0 top-full z-20 mt-1 overflow-hidden rounded-md border border-control bg-board shadow-[0_12px_24px_-12px_rgb(28_26_23/.35)]"
    >
      <ul
        :id="listId"
        ref="listbox"
        role="listbox"
        :aria-label="label"
        class="max-h-[min(22rem,60vh)] overflow-y-auto overscroll-contain"
      >
        <li
          v-for="(option, index) in options"
          :id="optionId(index)"
          :key="option.id"
          role="option"
          :aria-selected="index === activeIndex"
          :aria-disabled="option.disabled || undefined"
          class="flex min-h-13 cursor-pointer items-center border-l-2 border-transparent px-4 py-2 aria-disabled:cursor-default aria-selected:border-accent aria-selected:bg-elevated"
          @mousedown.prevent
          @click="choose(option)"
        >
          <slot name="option" :option="option" :active="index === activeIndex" />
        </li>
      </ul>
      <div v-if="!options.length" class="px-4 py-4 text-body-sm text-meta">
        <slot name="empty" />
      </div>
    </div>
  </div>
</template>
