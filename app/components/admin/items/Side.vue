<script setup lang="ts">
import { CircleCheck, CircleX, EyeOff, Trash2, TriangleAlert } from 'lucide-vue-next'
import type { ChecklistItem } from '~/utils/article-form'

/** Right column: status, verification, opinions, "Listo para publicar" and the delicate zone. Publishing itself lives in the header (and the bottom bar on mobile), not here. */
const props = defineProps<{
  live: boolean
  hidden: boolean
  publishedAt: string | null
  changes: number
  verifiedAt: string
  id: string
  reviews: number
  /** Average of user opinions; only shown with 3 or more. */
  average: number | null
  checklist: ChecklistItem[]
}>()
defineEmits<{ changes: []; hide: []; remove: [] }>()
const done = computed(() => props.checklist.filter((i) => i.ok).length)
const blockers = computed(() => props.checklist.filter((i) => i.blocking && !i.ok))
const date = adminDate
</script>

<template>
  <aside class="space-y-4 self-start xl:sticky xl:top-[108px]" aria-label="Publicación de la ficha">
    <section :class="admCard">
      <h2 class="border-b border-adm-line px-4 py-3 text-sm font-semibold">Publicación</h2>
      <div class="space-y-3 p-4 text-sm">
        <div class="flex items-center justify-between gap-2">
          <span class="text-adm-meta">Estado</span>
          <span class="flex items-center gap-2"><AdminStatusChip :status="live ? 'published' : hidden ? 'hidden' : 'draft'" :label="itemChipLabel(live ? 'published' : hidden ? 'hidden' : 'draft')" /><AdminTime v-if="live && publishedAt" :iso="publishedAt" short class="text-xs text-adm-meta" /></span>
        </div>
        <div v-if="live && changes" class="flex items-center justify-between gap-2">
          <span class="text-adm-meta">Sin publicar</span>
          <button type="button" class="inline-flex min-h-6 items-center rounded bg-adm-st-rev-bg px-1.5 py-0.5 text-xs font-medium text-adm-st-rev hover:underline max-md:min-h-11" @click="$emit('changes')">{{ changesLabel(changes) }} · ver</button>
        </div>
        <div class="flex items-center justify-between gap-2"><span class="text-adm-meta">Verificada</span><span class="tabular-nums">{{ verifiedAt ? date(verifiedAt) : 'Sin verificar' }}</span></div>
        <div class="flex items-center justify-between gap-2"><span class="text-adm-meta">Opiniones</span><NuxtLink :to="{ path: adminPath('opiniones'), query: { item: id } }" class="tabular-nums underline underline-offset-2">{{ reviews }}<template v-if="average !== null && reviews >= 3"> · {{ average.toFixed(1).replace('.', ',') }} de 5<span class="sr-only"> (nota media)</span></template></NuxtLink></div>
      </div>
      <div class="border-t border-adm-line p-4">
        <p class="mb-2 text-xs font-medium">Listo para publicar <span class="tabular-nums" :class="blockers.length ? 'text-adm-danger' : 'text-adm-ok'">{{ done }} / {{ checklist.length }}</span></p>
        <ul class="space-y-1.5 text-xs">
          <li v-for="item in checklist" :key="item.key" class="flex gap-2">
            <CircleCheck v-if="item.ok" class="mt-px size-3.5 flex-none text-adm-ok" aria-hidden="true" /><CircleX v-else-if="item.blocking" class="mt-px size-3.5 flex-none text-adm-danger" aria-hidden="true" /><TriangleAlert v-else class="mt-px size-3.5 flex-none text-adm-warn-icon" aria-hidden="true" />
            <span><span class="sr-only">{{ item.ok ? 'Hecho: ' : item.blocking ? 'Bloquea: ' : 'Aviso: ' }}</span>{{ item.label }}<template v-if="!item.ok && item.hint"> · <span class="text-adm-meta">{{ item.hint }}</span></template><AdminEditorChecklistLinks :item="item" /></span>
          </li>
        </ul>
        <p class="mt-2 text-xs text-adm-meta">{{ blockers.length ? 'Lo marcado como bloqueo impide publicar; lo demás solo avisa.' : 'Lo que no esté en verde solo avisa.' }}</p>
      </div>
    </section>
    <section :class="[admCard, 'space-y-2 p-4 text-sm']">
      <p class="text-xs font-medium">Zona delicada</p>
      <button v-if="live" type="button" :class="[admBtnGhost, 'w-full justify-start']" @click="$emit('hide')"><EyeOff aria-hidden="true" />Ocultar ficha…</button>
      <button type="button" :class="[admBtnDangerGhost, 'w-full justify-start']" :disabled="live || reviews > 0" :title="reviews ? `Tiene ${reviews} ${reviews === 1 ? 'opinión' : 'opiniones'} de usuarios: no se puede eliminar` : undefined" @click="$emit('remove')"><Trash2 aria-hidden="true" />Eliminar…</button>
      <p class="text-xs text-adm-meta">{{ live ? 'Una ficha publicada no se elimina: se oculta.' : reviews ? 'No se puede eliminar una ficha con opiniones de usuarios.' : 'Solo se eliminan las fichas que no están publicadas ni tienen opiniones.' }}</p>
    </section>
  </aside>
</template>
