<script setup lang="ts">
import { MoreHorizontal, Pencil, Plus, Search, ShieldCheck, Trash2 } from 'lucide-vue-next'
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuTrigger } from 'reka-ui'
import { kindLabel, langLabel, type AdminSource } from '~/utils/admin-ingest'
import { scopeLabel } from '~/utils/admin-news'

/**
 * Sources of the agent (README §19.4): search, kind filter and the table with the «Activa» switch in the row (cards under
 * 768). A source with news is never deleted, only deactivated. Names, domains and notes are interpolated.
 */
const props = defineProps<{ sources: readonly AdminSource[]; busy: boolean }>()
const emit = defineEmits<{ edit: [source: AdminSource]; create: []; toggle: [source: AdminSource, active: boolean]; remove: [source: AdminSource] }>()
const search = ref('')
const kind = ref<'all' | 'events' | 'news'>('all')
const kinds = [{ value: 'all' as const, label: 'Todas' }, { value: 'events' as const, label: 'Eventos' }, { value: 'news' as const, label: 'Noticias' }]
const fold = (t: string) => t.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
const shown = computed(() => props.sources.filter((s) => (kind.value === 'all' || s.kind === kind.value || s.kind === 'both') && (!search.value.trim() || fold(`${s.name} ${s.domain}`).includes(fold(search.value.trim())))))
const rate = (s: AdminSource) => (s.approvalRate == null ? '—' : `${Math.round(s.approvalRate * 100)} %`)
const seen = (s: AdminSource) => (s.lastSeenAt ? runDay(s.lastSeenAt) : '—')
const canRemove = (s: AdminSource) => !s.newsTotal && !s.eventsTotal
const th = 'h-9 px-3 text-left text-xs font-medium text-adm-meta'
const item = `${admMenuItem} cursor-pointer`
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2.5 md:px-6">
      <div class="relative w-full sm:w-64">
        <label for="src-q" class="sr-only">Buscar fuente</label>
        <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted" aria-hidden="true" />
        <input id="src-q" v-model="search" type="search" :class="[admInput, 'pl-8 [&::-webkit-search-cancel-button]:hidden']" placeholder="Buscar fuente" autocomplete="off" />
      </div>
      <AdminSegmented v-model="kind" label="Tipo" :options="kinds" />
      <button type="button" :class="[admBtnPrimary, 'sm:ml-auto']" @click="emit('create')"><Plus aria-hidden="true" />Nueva fuente</button>
    </div>

    <AdminStateBlock v-if="!shown.length" :kind="sources.length ? 'no-results' : 'empty'" :title="sources.length ? undefined : 'Todavía no hay fuentes'" :description="sources.length ? 'Ninguna fuente coincide. Prueba con otra palabra.' : 'Sin fuentes activas, la rutina no tiene de dónde recoger.'" />
    <template v-else>
      <div class="hidden overflow-x-auto md:block">
        <table class="w-full min-w-[640px] border-collapse text-[13px]">
          <caption class="sr-only">Fuentes de la rutina</caption>
          <thead class="border-b border-adm-line"><tr>
            <th :class="th">Fuente</th><th :class="th">Para</th><th :class="th">Alcance</th><th :class="[th, 'max-lg:hidden']">Idioma</th><th :class="[th, 'max-xl:hidden']">Última vez</th><th :class="[th, 'text-right max-lg:hidden']">Aprobadas</th><th :class="th">Activa</th><th :class="[th, 'w-10']"><span class="sr-only">Acciones</span></th>
          </tr></thead>
          <tbody>
            <tr v-for="s in shown" :key="s.id" :class="['border-b border-adm-line', !s.active && 'text-adm-meta']">
              <td class="h-14 px-3"><span :class="['block font-medium', s.active && 'text-adm-fg']">{{ s.name }}</span><span class="flex flex-wrap items-center gap-1.5"><span class="font-mono text-xs text-adm-meta">{{ s.domain }}</span><span v-if="s.trusted" :class="[admChip, 'bg-adm-subtle text-adm-meta']"><ShieldCheck aria-hidden="true" />De confianza</span></span></td>
              <td class="px-3">{{ kindLabel(s.kind) }}</td>
              <td class="px-3">{{ scopeLabel(s.scope) }}</td>
              <td class="px-3 max-lg:hidden">{{ langLabel(s.lang) }}</td>
              <td class="px-3 max-xl:hidden">{{ seen(s) }}</td>
              <td class="px-3 text-right tabular-nums max-lg:hidden">{{ rate(s) }}</td>
              <td class="px-3"><AdminSwitch :model-value="s.active" :label="`${s.name}: ${s.active ? 'activa' : 'inactiva'}`" :disabled="busy" class="[&_label]:sr-only" @update:model-value="(v: boolean) => emit('toggle', s, v)" /></td>
              <td class="px-1">
                <DropdownMenuRoot>
                  <DropdownMenuTrigger :class="admIconBtn" :aria-label="`Acciones de ${s.name}`"><MoreHorizontal aria-hidden="true" /></DropdownMenuTrigger>
                  <DropdownMenuPortal>
                    <DropdownMenuContent align="end" :side-offset="4" :class="[admPopover, 'admin font-sans']">
                      <DropdownMenuItem :class="item" @select="emit('edit', s)"><Pencil aria-hidden="true" />Editar</DropdownMenuItem>
                      <DropdownMenuItem :class="[item, 'text-adm-danger! [&_svg]:text-adm-danger!']" :disabled="!canRemove(s)" @select="emit('remove', s)"><Trash2 aria-hidden="true" /><span class="flex flex-col"><span>Eliminar…</span><span v-if="!canRemove(s)" class="text-xs text-adm-meta">Tiene historial: se desactiva</span></span></DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenuPortal>
                </DropdownMenuRoot>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <ul class="divide-y divide-adm-line md:hidden" aria-label="Fuentes de la rutina">
        <li v-for="s in shown" :key="s.id" class="flex items-center gap-2 px-4 py-3">
          <div class="min-w-0 flex-1"><p class="truncate text-sm font-medium">{{ s.name }}</p><p class="truncate text-xs text-adm-meta">{{ kindLabel(s.kind) }} · {{ scopeLabel(s.scope) }} · {{ rate(s) }} aprobadas</p></div>
          <AdminSwitch :model-value="s.active" :label="`${s.name}: ${s.active ? 'activa' : 'inactiva'}`" :disabled="busy" class="[&_label]:sr-only" @update:model-value="(v: boolean) => emit('toggle', s, v)" />
          <button type="button" :class="admIconBtn" :aria-label="`Editar ${s.name}`" @click="emit('edit', s)"><Pencil aria-hidden="true" /></button>
        </li>
      </ul>
    </template>
    <p class="border-t border-adm-line px-4 py-3 text-xs text-adm-meta md:px-6">La rutina solo lee las fuentes activas. Una fuente con noticias o eventos no se elimina, se desactiva: así el historial conserva de dónde salió cada cosa.</p>
  </div>
</template>
