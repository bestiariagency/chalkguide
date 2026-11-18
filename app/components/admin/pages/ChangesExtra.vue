<script setup lang="ts">
import { Clock, TriangleAlert } from 'lucide-vue-next'
import type { PageRevision } from '~/services/admin/page-drafts'
import { PAGE_DELAY } from '~/utils/admin-pages'

/** What the "Publicar cambios" dialog adds for pages: the date choice (legal, if the text changed), provisional marks and the real delay. */
defineProps<{ legal: boolean; textChanged: boolean; today: string; previous: string | null; marks: number }>()
defineEmits<{ review: [] }>()
const revision = defineModel<PageRevision>({ default: 'today' })
</script>

<template>
  <div class="mt-4 space-y-3 text-[13px]">
    <AdminPagesRevisionChoice v-if="legal && textChanged" v-model="revision" :today="today" :previous="previous" />
    <p v-else-if="legal" class="text-adm-meta">La «Última actualización» no cambia: no has tocado ni el título ni el texto.</p>
    <p v-if="marks" class="flex gap-2 rounded-lg bg-adm-warn-soft p-3" role="status">
      <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
      <span>Quedan <b>{{ marks === 1 ? '1 marca' : `${marks} marcas` }} de texto provisional</b>. Se publicarían tal cual. <button type="button" class="font-medium underline underline-offset-2 max-md:min-h-11" @click="$emit('review')">Revisarlas</button></span>
    </p>
    <p class="flex gap-2 rounded-lg bg-adm-subtle p-3" role="note"><Clock class="mt-0.5 size-4 flex-none" aria-hidden="true" />{{ PAGE_DELAY }} La versión en inglés solo cambia si has tocado el inglés.</p>
  </div>
</template>
