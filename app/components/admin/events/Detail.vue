<script setup lang="ts">
import { CalendarX, ChevronDown, ChevronUp, Copy, ExternalLink, Sparkles, X } from 'lucide-vue-next'
import { confidenceWord, eventTypeLabel, inferredHas, placeOf, previewOf, isGymPlace, type AdminEvent } from '~/utils/admin-events'
import { dayLabel, timeLabel } from '~/utils/admin-madrid'

/**
 * Detail of a draft in the inbox (read only): the preview as the site will show it, the data (what the agent
 * guessed is marked "deducido"), what the agent found and the decision buttons. In the sheet (< 1024) the
 * title is the dialog's and the actions sit in its footer.
 */
const props = defineProps<{ event: AdminEvent; busy: boolean; sheet?: boolean }>()
const emit = defineEmits<{ approve: []; edit: []; reject: [reason: string | null]; prev: []; next: []; openEvent: [id: string]; duplicate: []; remove: [] }>()
const rejectOpen = defineModel<boolean>('rejectOpen', { default: false })

const ROWS = [
  { key: 'type', label: 'Tipo' },
  { key: 'start', label: 'Cuándo' },
  { key: 'place', label: 'Dónde' },
  { key: 'price', label: 'Precio' },
  { key: 'url', label: 'Organizador' },
  { key: 'title_en', label: 'Título EN' },
]
/** "When" also covers the end and the all-day flag, which the agent may have guessed. */
const guessed = (key: string) => (key === 'start' ? ['start', 'end', 'all_day'].some((k) => inferredHas(props.event, k)) : inferredHas(props.event, key))

const original = useAdminEventLookup(() => props.event.duplicate?.id)
const preview = computed(() => previewOf(props.event))
const headId = `ev-detail-${useId()}`
const found = computed(() => {
  const at = collectedAt(props.event)
  return at ? { runAt: runLabel(at), at: adminDateTime(at) } : null
})
const flags = computed(() => sourceFlags(props.event.sourceUrl, props.event.agent?.note))
</script>

<template>
  <article :aria-labelledby="sheet ? undefined : headId" class="flex min-h-0 flex-1 flex-col">
    <header v-if="!sheet" class="sticky top-0 z-10 flex h-12 flex-none bg-adm-bg items-center gap-2 border-b border-adm-line px-6">
      <h2 :id="headId" class="truncate text-base font-semibold">{{ event.titleEs }}</h2>
      <span class="ml-auto flex flex-none gap-1">
        <button type="button" :class="admIconBtn" aria-label="Anterior (K)" @click="emit('prev')"><ChevronUp aria-hidden="true" /></button>
        <button type="button" :class="admIconBtn" aria-label="Siguiente (J)" @click="emit('next')"><ChevronDown aria-hidden="true" /></button>
        <AdminEventsRowMenu :event="event" @edit="emit('edit')" @duplicate="emit('duplicate')" @remove="emit('remove')" />
      </span>
    </header>

    <div :class="['max-w-[720px] space-y-5', sheet ? '' : 'p-6']">
      <div class="flex flex-wrap items-center gap-2">
        <AdminEventsChip :event="event" /><AdminEventsOrigin :source="event.source" /><AdminEventsFlags :event="event" />
      </div>

      <AdminSourceCard
        v-if="event.sourceUrl"
        :url="event.sourceUrl"
        :run-label="found ? found.runAt : undefined"
        :run-to="event.runId ? `${adminPath('ingesta')}?recogida=${event.runId}` : undefined"
        :punycode="flags.punycode"
        :unlisted="flags.unlisted"
      />

      <p v-if="event.isPast" class="flex items-start gap-2 rounded-lg bg-adm-danger-soft px-3 py-2 text-[13px] leading-5 text-adm-danger" role="status">
        <CalendarX class="mt-0.5 size-4 flex-none" aria-hidden="true" />
        <span>Fue el <b>{{ dayLabel(event.startsAt) }}</b>. Ya no saldría en la agenda: descártalo para que el agente lo recuerde, o cambia la fecha.</span>
      </p>
      <div v-if="event.duplicate" class="flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5 text-adm-warn">
        <Copy class="mt-0.5 size-4 flex-none" aria-hidden="true" />
        <div class="min-w-0 flex-1">
          <p>
            Parece el mismo que
            <b v-if="original">«{{ original.titleEs }}»</b><b v-else>otro evento</b>,
            <template v-if="original">{{ original.status === 'draft' ? 'también por aprobar' : original.status === 'rejected' ? 'ya descartado' : 'ya en la agenda' }} ({{ dayLabel(original.startsAt) }}<template v-if="placeOf(original)">, {{ placeOf(original) }}</template>)</template>.
          </p>
          <div class="mt-2 flex flex-wrap gap-2">
            <button type="button" :class="admBtnGhost" @click="emit('openEvent', event.duplicate.id)"><ExternalLink aria-hidden="true" />Abrir el existente</button>
            <button type="button" :class="admBtnGhost" :disabled="busy" @click="emit('reject', 'duplicate')"><X aria-hidden="true" />Descartar como duplicado</button>
          </div>
        </div>
      </div>

      <AdminEventsPreview :data="preview" selector />

      <dl class="text-sm">
        <div v-for="row in ROWS" :key="row.key" class="grid grid-cols-[112px_minmax(0,1fr)] gap-3 border-b border-adm-line py-2">
          <dt class="text-adm-meta">{{ row.label }}</dt>
          <dd class="min-w-0">
            <template v-if="row.key === 'type'">{{ eventTypeLabel(event.type) }}</template>
            <span v-else-if="row.key === 'start'" class="tabular-nums">{{ dayLabel(event.startsAt) }} · {{ timeLabel(event) }}</span>
            <template v-else-if="row.key === 'place'">
              <NuxtLink v-if="isGymPlace(event)" :to="adminPath(`rocodromos/${event.itemId}`)" class="underline underline-offset-2">{{ event.itemName }}</NuxtLink>
              <template v-else-if="event.locationText">{{ event.locationText }}</template>
              <span v-else class="text-adm-muted">Sin lugar</span>
              <span v-if="isGymPlace(event)" class="text-adm-meta"> · ficha</span>
            </template>
            <template v-else-if="row.key === 'price'">{{ event.priceText ?? '' }}<span v-if="!event.priceText" class="text-adm-muted">Sin precio</span></template>
            <template v-else-if="row.key === 'url'">
              <a v-if="safeHref(event.url)" :href="event.url!" target="_blank" :rel="SOURCE_LINK_REL" class="break-all underline underline-offset-2">{{ event.url }}<span class="sr-only"> (se abre en otra pestaña)</span></a>
              <span v-else class="text-adm-muted">Sin enlace</span>
            </template>
            <template v-else>{{ event.titleEn ?? '' }}<span v-if="!event.titleEn" class="text-adm-muted">Falta · no sale en /en</span></template>
            <span v-if="guessed(row.key)" class="ml-1 inline-flex items-center gap-0.5 text-[11px] text-adm-meta"><Sparkles class="size-3" aria-hidden="true" />deducido</span>
          </dd>
        </div>
      </dl>

      <section v-if="event.agent" class="space-y-3 rounded-lg border border-adm-line bg-adm-side p-4 text-sm" :aria-labelledby="`${headId}-ag`">
        <h3 :id="`${headId}-ag`" class="flex items-center gap-2 font-semibold"><Sparkles class="size-4 text-adm-meta" aria-hidden="true" />Qué encontró el agente</h3>
        <dl class="grid grid-cols-[112px_minmax(0,1fr)] gap-x-3 gap-y-1.5">
          <template v-if="found"><dt class="text-adm-meta">Encontrado</dt><dd class="tabular-nums">{{ found.at }}</dd></template>
          <dt class="text-adm-meta">Confianza</dt><dd><AdminEventsConfidence :value="event.agent.confidence" label /></dd>
        </dl>
        <p v-if="event.agent.note"><span class="text-adm-meta">Nota:</span> {{ event.agent.note }}</p>
        <blockquote v-if="event.agent.excerpt" class="border-l-2 border-adm-line-strong pl-3 text-adm-meta" lang="ca">{{ event.agent.excerpt }}</blockquote>
        <p class="sr-only">Confianza {{ confidenceWord(event.agent.confidence) }}</p>
      </section>
      <p v-else class="text-xs text-adm-meta">Lo creaste tú el <AdminTime :iso="event.createdAt" short /> y lo guardaste como borrador.</p>

      <p class="rounded-lg border border-adm-line p-3 text-xs text-adm-meta">
        Al aprobar sale en /agenda<template v-if="event.hasEn"> y /en/agenda</template> y, si es de este mes, en la pizarra de la home, en menos de 10 minutos. Puedes retirarlo cuando quieras.
      </p>
    </div>

    <AdminEventsActions v-if="!sheet" v-model:reject-open="rejectOpen" class="px-6 pb-6" :event="event" :busy="busy" @approve="emit('approve')" @edit="emit('edit')" @reject="(reason) => emit('reject', reason)" />
  </article>
</template>
