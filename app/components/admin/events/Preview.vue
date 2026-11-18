<script setup lang="ts">
import { Ban, EyeOff } from 'lucide-vue-next'
import { eventTypeLabel, type EventPreview } from '~/utils/admin-events'

/**
 * "Así sale en la agenda": same structure as the site's `EventDetails` (title, place · time · price, type and
 * organizer link), in Spanish or English. Without an English title the event is not in /en/agenda.
 */
const props = defineProps<{ data: EventPreview; selector?: boolean }>()
const lang = ref<'es' | 'en'>('es')
const title = computed(() => (lang.value === 'en' ? props.data.titleEn : props.data.titleEs).trim())
const missing = computed(() => lang.value === 'en' && !props.data.titleEn.trim())
const meta = computed(() => [props.data.time, props.data.price.trim()].filter(Boolean))
const langs = [{ value: 'es' as const, label: 'ES' }, { value: 'en' as const, label: 'EN' }]
const headId = `pv-${useId()}`
</script>

<template>
  <section :aria-labelledby="headId">
    <div class="mb-2 flex items-center gap-2">
      <h3 :id="headId" class="text-xs font-medium text-adm-meta">Así sale en la agenda<span class="font-normal"> · aproximado</span></h3>
      <AdminSegmented v-if="selector" v-model="lang" class="ml-auto" label="Idioma de la vista previa" :options="langs" />
    </div>
    <div class="rounded-lg border border-adm-line bg-adm-side p-3">
      <p v-if="missing" class="flex gap-2 text-sm text-adm-meta"><EyeOff class="mt-0.5 size-4 flex-none" aria-hidden="true" />No sale en /en/agenda: falta el título en inglés.</p>
      <div v-else class="flex gap-3" :lang="lang">
        <AdminEventsDateBlock v-if="data.startsAt" :iso="data.startsAt" />
        <div class="min-w-0 text-sm">
          <span :class="['block leading-snug font-medium', data.cancelled && 'text-adm-meta line-through']">{{ title || 'Sin título' }}</span>
          <span v-if="data.place || meta.length" class="mt-0.5 block text-xs text-adm-meta">
            <span v-if="data.place" :class="data.gym && 'underline underline-offset-2'">{{ data.place }}</span>
            <template v-if="data.place && meta.length"> · </template>
            <span v-for="(item, i) in meta" :key="item" class="font-mono whitespace-nowrap">{{ item }}{{ i < meta.length - 1 ? ' · ' : '' }}</span>
          </span>
          <span class="mt-2 flex flex-wrap items-center gap-3">
            <span v-if="data.cancelled" :class="[admChip, 'bg-adm-subtle text-adm-meta outline-1 -outline-offset-1 outline-dashed outline-adm-line-strong']"><Ban aria-hidden="true" />{{ lang === 'en' ? 'Cancelled' : 'Cancelado' }}</span>
            <span :class="[admChip, 'bg-adm-subtle text-adm-meta']">{{ eventTypeLabel(data.type, lang) }}</span>
            <span v-if="data.hasUrl" class="text-xs underline underline-offset-2">{{ lang === 'en' ? 'More information' : 'Más información' }}</span>
          </span>
        </div>
      </div>
    </div>
  </section>
</template>
