<script setup lang="ts">
import { Loader2, TriangleAlert } from 'lucide-vue-next'
import { articleDisplay } from '~/utils/admin-articles'
import { pluralArticles } from '~/utils/admin-categories'
import { publishedText, type AdminAuthor } from '~/utils/admin-authors'

/**
 * Delete an author (README §17.6; `alertdialog`, focus on «Cancelar»). Their articles pass at once to
 * the site author, also the published ones (no «Publicar cambios»), so the dialog says how many, shows
 * the first three titles and puts the number in the button. Counts come from the database on opening.
 */
const props = defineProps<{ author: AdminAuthor; siteName: string | null; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [moved: number] }>()

const { impact, pending, failed, reload } = useAdminAuthorImpact(props.author.id)
const total = computed(() => impact.value?.counts.total ?? 0)
const live = computed(() => impact.value?.counts.live ?? 0)
const siteName = computed(() => props.siteName?.trim() || '')
/** «a Xavi» / «al autor del sitio» (never «a el»). */
const dest = computed(() => (siteName.value ? `a ${siteName.value}` : 'al autor del sitio'))
const more = computed(() => Math.max(0, total.value - (impact.value?.titles.length ?? 0)))
const description = computed(() => {
  if (pending.value || failed.value) return undefined
  if (!total.value) return `No firma ningún artículo. Se elimina el autor.${props.author.photo ? ' Su foto se queda en Medios.' : ''}`
  return `Firma ${pluralArticles(total.value)} (${publishedText(live.value)}). Pasarán a firmarlos ${siteName.value ? `${siteName.value}, el autor del sitio` : 'el autor del sitio'}.`
})
const label = computed(() => (total.value ? `Eliminar y pasar ${pluralArticles(total.value)} ${dest.value}` : 'Eliminar'))
</script>

<template>
  <AdminModal v-model:open="open" alert stacked :title="`¿Eliminar a «${author.name}»?`" :description="description" :busy="busy">
    <p v-if="pending" class="text-sm text-adm-meta" role="status">Comprobando sus artículos…</p>
    <div v-else-if="failed" class="space-y-2 text-sm" role="alert">
      <p>No se han podido comprobar sus artículos, así que no se puede eliminar todavía.</p>
      <button type="button" :class="admBtnGhost" @click="reload">Reintentar</button>
    </div>
    <div v-else-if="total" class="space-y-3 text-sm">
      <ul class="divide-y divide-adm-line rounded-lg border border-adm-line" aria-label="Primeros artículos que firma">
        <li v-for="t in impact?.titles" :key="t.id" class="flex min-h-10 items-center gap-2 px-3 py-1.5">
          <span class="min-w-0 flex-1 truncate">{{ t.title || 'Sin título' }}</span>
          <AdminStatusChip :status="articleDisplay(t)" />
        </li>
        <li v-if="more" class="px-3 py-1.5 text-xs text-adm-meta">y {{ more }} más</li>
      </ul>
      <div class="flex gap-2 rounded-md bg-adm-warn-soft px-3 py-2.5 text-adm-warn">
        <TriangleAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" />
        <span>
          <template v-if="live">En los publicados la firma cambia <b>al momento</b>, sin «Publicar cambios». </template>Los borradores y los programados {{ live ? 'también ' : '' }}pasan {{ dest }} y no se puede deshacer en bloque.
          <template v-if="author.photo"> Su foto se queda en Medios.</template>
        </span>
      </div>
    </div>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnDanger" :disabled="busy || pending || failed" :aria-busy="busy || undefined" @click="emit('confirm', total)">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />{{ label }}
      </button>
    </template>
  </AdminModal>
</template>
