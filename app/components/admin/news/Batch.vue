<script setup lang="ts">
import { SquarePlay, TriangleAlert } from 'lucide-vue-next'
import { splitByWarnings, warningText, type AdminNews } from '~/utils/admin-news'

/**
 * Batch approval with warnings (D77): it only opens when some selected item has warnings. Three ways out: Cancelar, Aprobar las N
 * and Aprobar las M sin avisos (primary), so the quick path never publishes the doubtful ones blind.
 */
const props = defineProps<{ rows: readonly AdminNews[]; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ all: []; clean: [] }>()
const split = computed(() => splitByWarnings(props.rows))
const withVideo = computed(() => props.rows.filter((r) => r.videos.length))
const n = (count: number) => `${count} ${count === 1 ? 'tiene' : 'tienen'}`
</script>

<template>
  <AdminModal v-model:open="open" :title="`Aprobar ${rows.length} noticias`" :busy="busy" :description="split.warned.length ? `${n(split.warned.length)} avisos. Revísalas antes o apruébalas solo si ya las has comprobado.` : 'Ninguna tiene avisos, pero algunas llevan vídeo: revisa su crédito antes de publicar.'">
    <ul v-if="split.warned.length" class="divide-y divide-adm-line rounded-lg border border-adm-line">
      <li v-for="r in split.warned" :key="r.id" class="flex items-start gap-2 px-3 py-2">
        <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
        <span class="min-w-0 flex-1"><span class="block truncate text-sm">{{ r.titleEs }}</span><span class="text-xs text-adm-meta">{{ r.warnings.map((w) => warningText(w, r)).join(' · ') }}</span></span>
      </li>
    </ul>
    <section v-if="withVideo.length" class="mt-3" aria-label="Noticias con vídeo">
      <p class="text-xs font-medium">Con vídeo: salen publicados con el crédito que ves aquí. Según la rutina, sin verificar.</p>
      <ul class="mt-1.5 divide-y divide-adm-line rounded-lg border border-adm-line">
        <li v-for="r in withVideo" :key="r.id" class="flex items-start gap-2 px-3 py-2">
          <SquarePlay class="mt-0.5 size-4 flex-none text-adm-meta" aria-hidden="true" />
          <span class="min-w-0 flex-1"><span class="block truncate text-sm">{{ r.titleEs }}</span><span v-for="v in r.videos" :key="v.youtubeId" class="block truncate text-xs text-adm-meta">{{ v.title || 'Sin título' }} · {{ v.channel || 'sin canal' }} · <span class="font-mono">{{ v.youtubeId }}</span></span></span>
        </li>
      </ul>
    </section>
    <p class="mt-3 text-xs text-adm-meta">Se publican en menos de 10 minutos. Cada una se puede retirar después desde Publicadas.</p>
    <template #footer>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="split.warned.length ? admBtnGhost : admBtnPrimary" :disabled="busy" :data-autofocus="split.warned.length ? undefined : true" @click="emit('all')">Aprobar las {{ rows.length }}</button>
      <button v-if="split.warned.length && split.clean.length" type="button" :class="admBtnPrimary" :disabled="busy" data-autofocus @click="emit('clean')">Aprobar las {{ split.clean.length }} sin avisos</button>
    </template>
  </AdminModal>
</template>
