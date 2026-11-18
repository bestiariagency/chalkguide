<script setup lang="ts">
import { CircleAlert } from 'lucide-vue-next'

/** 22px checkbox with a drawn check. Unchecked by default (newsletter consent rule). */
defineOptions({ inheritAttrs: false })
const { rootAttrs, controlAttrs } = useSplitAttrs()
const props = defineProps<{ id?: string; error?: string }>()
const model = defineModel<boolean>({ default: false })
const autoId = useId()
const controlId = computed(() => props.id ?? `check-${autoId}`)
const errorId = computed(() => `${controlId.value}-error`)
const input = ref<HTMLInputElement | null>(null)
defineExpose({ focus: () => input.value?.focus() })
</script>

<template>
  <div v-bind="rootAttrs">
    <label :for="controlId" class="relative flex min-h-11 cursor-pointer items-start gap-3 py-2">
      <input
        :id="controlId"
        ref="input"
        v-model="model"
        type="checkbox"
        v-bind="controlAttrs"
        :aria-invalid="error ? true : undefined"
        :aria-describedby="error ? errorId : undefined"
        class="peer absolute top-[.6rem] left-0 m-0 size-5.5 opacity-0"
      />
      <span
        class="mt-0.5 grid size-5.5 shrink-0 place-items-center rounded-sm border border-control bg-elevated transition-colors duration-200 ease-standard peer-checked:border-accent-fill peer-checked:bg-accent-fill peer-focus-visible:ring-focus peer-aria-invalid:border-danger-text"
        aria-hidden="true"
      >
        <svg width="13" height="13" viewBox="0 0 14 14">
          <path
            d="M2.5 7.5l3 3 6-7"
            fill="none"
            class="stroke-on-accent transition-[stroke-dashoffset] delay-[50ms] duration-300 ease-out [stroke-dasharray:20]"
            :class="model ? '[stroke-dashoffset:0]' : '[stroke-dashoffset:20]'"
            stroke-width="2.2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </span>
      <span class="text-body-sm"><slot /></span>
    </label>
    <!-- Outside the <label>: a control here (e.g. "More information") never toggles the box. 34px = box 22 + gap 12. -->
    <div v-if="$slots.after" class="pl-8.5"><slot name="after" /></div>
    <p
      v-if="error"
      :id="errorId"
      class="mt-1 flex items-center gap-1.5 text-body-sm text-danger-text"
    >
      <CircleAlert :size="16" aria-hidden="true" />{{ error }}
    </p>
  </div>
</template>
