<script setup lang="ts">
import { Check, CircleAlert, Info, X } from 'lucide-vue-next'
import type { ToastItem } from '~/types/ui'

const props = defineProps<{ toast: ToastItem }>()
const emit = defineEmits<{ dismiss: [] }>()
const { t } = useI18n()

const icon = computed(() => ({ success: Check, error: CircleAlert, info: Info })[props.toast.type])
const iconColor = computed(
  () =>
    ({ success: 'text-success-text', error: 'text-danger-text', info: 'text-foreground' })[
      props.toast.type
    ],
)
</script>

<template>
  <div
    :role="toast.type === 'error' ? 'alert' : 'status'"
    class="pointer-events-auto flex items-start gap-3 rounded-lg border-[0.5px] border-line-strong bg-elevated py-3 pr-3 pl-3.5 text-foreground"
  >
    <component :is="icon" :size="20" class="mt-0.5" :class="iconColor" aria-hidden="true" />
    <div class="flex-1">
      <p class="text-body-sm">{{ toast.title }}</p>
      <p v-if="toast.body" class="text-caption text-meta">{{ toast.body }}</p>
    </div>
    <button
      type="button"
      class="-m-2 grid size-11 place-items-center rounded-md text-meta hover:text-foreground"
      :aria-label="t('common.close')"
      @click="emit('dismiss')"
    >
      <X :size="16" aria-hidden="true" />
    </button>
  </div>
</template>
