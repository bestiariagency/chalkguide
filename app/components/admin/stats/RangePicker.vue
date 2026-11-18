<script setup lang="ts">
import { fmtDay } from '~/utils/admin-stats-format'

/**
 * Custom range picker (README §16.10): popover under the controls from 768 px, bottom sheet (modal, focus trapped)
 * below. Esc and «Cancelar» close it and the focus goes back to whoever opened it. The popover is a dialog inside
 * the controls (the parent closes it on a click outside).
 */
const props = defineProps<{ desktop: boolean; from: string; to: string; today: string; cutoff: string }>()
const open = defineModel<boolean>('open', { required: true })
const emit = defineEmits<{ apply: [from: string, to: string]; close: [] }>()

const help = computed(() => `Días completos en hora de Madrid, del ${fmtDay(props.cutoff)} a hoy (se guardan 24 meses).`)
const id = useId()
</script>

<template>
  <AdminModal v-if="!desktop" v-model:open="open" title="Rango personalizado" :description="help" @update:open="(v: boolean) => !v && emit('close')">
    <AdminStatsRangeForm :from="from" :to="to" :today="today" :cutoff="cutoff" @apply="(a, b) => emit('apply', a, b)" @cancel="open = false" />
  </AdminModal>
  <div
    v-else-if="open" role="dialog" :aria-labelledby="`${id}-t`" :aria-describedby="`${id}-d`"
    class="absolute top-full right-0 z-40 mt-2 w-[360px] animate-adm-fade rounded-[10px] border border-adm-line bg-adm-elev px-4 pt-4 pb-4 shadow-adm-pop motion-reduce:animate-none"
    @keydown.esc.stop="open = false; emit('close')"
  >
    <h2 :id="`${id}-t`" class="text-sm font-semibold">Rango personalizado</h2>
    <p :id="`${id}-d`" class="mt-0.5 mb-3 text-xs text-adm-meta">{{ help }}</p>
    <AdminStatsRangeForm :from="from" :to="to" :today="today" :cutoff="cutoff" @apply="(a, b) => emit('apply', a, b)" @cancel="open = false; emit('close')" />
  </div>
</template>
