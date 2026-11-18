<script setup lang="ts">
import { Calendar, X } from 'lucide-vue-next'
import { dateChipLabel, localeName, sourceLabel, STATUS_FILTERS, type SubscriberFilters } from '~/utils/admin-subscribers'
import { RELATED_FILTERS, relatedSlug } from '~/utils/admin-subscribers-related'

/** Active filters as removable chips plus "Quitar filtros". Everything is in the URL, so removing one is a navigation. */
const props = defineProps<{ filters: SubscriberFilters; showStatuses: boolean }>()
const emit = defineEmits<{ filter: [patch: Record<string, string | undefined>]; remove: [key: 'origen' | 'version' | 'estado' | 'afines', value: string]; clear: [] }>()
const chip = 'inline-flex h-6 items-center gap-1 rounded-full border border-adm-line-strong bg-adm-elev pr-1 pl-2.5 text-xs hover:border-adm-control max-md:h-8'
const dates = computed(() => dateChipLabel(props.filters))
</script>

<template>
  <div class="flex flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2 text-xs md:px-6">
    <span class="text-adm-meta">Filtros:</span>
    <button v-for="s in filters.sources" :key="`o-${s}`" type="button" :class="chip" @click="emit('remove', 'origen', s)">{{ sourceLabel(s) }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
    <button v-if="filters.locale" type="button" :class="chip" @click="emit('filter', { idioma: undefined })">{{ localeName(filters.locale) }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
    <button v-if="dates" type="button" :class="chip" @click="emit('filter', { desde: undefined, hasta: undefined, fecha: undefined })"><Calendar class="size-3.5" aria-hidden="true" />{{ dates }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
    <button v-for="v in filters.versions" :key="`v-${v}`" type="button" :class="chip" @click="emit('remove', 'version', String(v))">Texto v{{ v }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
    <button v-for="r in filters.related" :key="`a-${r}`" type="button" :class="chip" @click="emit('remove', 'afines', relatedSlug(r))">Afines: {{ RELATED_FILTERS.find((f) => f.value === r)?.label }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
    <template v-if="showStatuses">
      <button v-for="s in filters.statuses" :key="`s-${s}`" type="button" :class="chip" @click="emit('remove', 'estado', s)">{{ STATUS_FILTERS.find((f) => f.value === s)?.label }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
    </template>
    <button type="button" :class="[admBtnGhost, 'ml-1']" @click="emit('clear')">Quitar filtros</button>
  </div>
</template>
