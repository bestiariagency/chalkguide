<script setup lang="ts">
import { EyeOff } from 'lucide-vue-next'

/**
 * Status badge: always text + dot/icon, never colour alone. `revised` is the composed
 * "Publicado · N cambios" (violet = unpublished changes, exclusive to that meaning).
 * `hidden` has a dashed outline and an eye-off icon.
 */
const props = defineProps<{
  status: AdminStatusKind
  /** Unpublished changes (only for `revised`). */
  changes?: number
  /** Replaces the default label ("Oculta" for comments). */
  label?: string
}>()
const def = computed(() => ADMIN_STATUS[props.status])
const text = computed(() => props.label ?? def.value.label)
const count = computed(() => props.changes ?? 1)
</script>

<template>
  <span
    v-if="status === 'revised'"
    class="inline-flex h-5 items-center overflow-hidden rounded"
    :aria-label="`${text}, con ${changesLabel(count)} sin publicar`"
    role="group"
  >
    <span :class="[admChip, def.tone, 'rounded-none']"><span class="size-1.5 flex-none rounded-full bg-current" aria-hidden="true" />{{ text }}</span>
    <span :class="[admChip, 'rounded-none bg-adm-st-rev-bg text-adm-st-rev shadow-[inset_1px_0_0_rgb(255_255_255/0.7)]']">{{ changesLabel(count) }}</span>
  </span>
  <span v-else :class="[admChip, def.tone]">
    <EyeOff v-if="def.icon === 'eye-off'" aria-hidden="true" />
    <span v-else class="size-1.5 flex-none rounded-full bg-current" aria-hidden="true" />
    {{ text }}
  </span>
</template>
