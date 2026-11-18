<script setup lang="ts">
import { CircleAlert, CircleX, Clock, EyeOff, Globe, Info, Languages, Loader2, Lock, TriangleAlert, Upload } from 'lucide-vue-next'
import { PAGE_DELAY, type PageDef } from '~/utils/admin-pages'
import type { PageChecklistItem } from '~/utils/page-form'

/**
 * First publication of a page (modal): what happens on the site, the "Última actualización" of legal
 * pages (today: there is no earlier date), provisional marks as a warning and the blockers. Later edits
 * go through the draft of changes ("Publicar cambios").
 */
const props = defineProps<{
  def: PageDef
  checklist: PageChecklistItem[]
  busy: boolean
  today: string
  noindex: boolean
  /** Provisional marks left in the text (warning only). */
  marks: number
  /** Message of the last refused publication. */
  error: string
}>()
defineEmits<{ publish: []; review: [] }>()
const open = defineModel<boolean>('open', { default: false })

const blockers = computed(() => props.checklist.filter((i) => i.blocking && !i.ok))
const row = 'flex gap-2'
const icon = 'mt-0.5 size-4 flex-none text-adm-meta'
</script>

<template>
  <AdminModal v-model:open="open" size="md" :busy="busy" :title="`Publicar «${def.label}»`" description="Primera publicación. Después, cada edición será un borrador de cambios.">
    <ul class="space-y-2 text-sm">
      <li :class="row"><Globe :class="icon" aria-hidden="true" /><span><span class="font-mono text-xs">{{ def.routeEs }}</span> deja de decir «Esta página aún no está publicada» y muestra este texto.</span></li>
      <li :class="row"><EyeOff :class="icon" aria-hidden="true" /><span>{{ def.legal ? 'Seguirá sin salir en buscadores: las páginas legales nunca se muestran.' : noindex ? 'No saldrá en buscadores: tiene «No indexar» activado.' : 'Podrá salir en buscadores.' }}</span></li>
      <li :class="row"><Languages :class="icon" aria-hidden="true" /><span>Se publica en español. El inglés solo sale si está completo (título y cuerpo).</span></li>
      <li v-if="def.legal" :class="row"><Lock :class="icon" aria-hidden="true" /><span>Una vez publicada, una página legal no se despublica: se corrige con cambios.</span></li>
      <li :class="row"><Clock :class="icon" aria-hidden="true" /><span>{{ PAGE_DELAY }}</span></li>
    </ul>

    <div class="mt-4 space-y-3 text-sm">
      <AdminPagesRevisionChoice v-if="def.legal" model-value="today" :today="today" :previous="null" hint="Recomendado: es la primera versión publicada." />
      <p v-if="marks" class="flex gap-2 rounded-lg bg-adm-warn-soft p-3 text-[13px]" role="status">
        <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
        <span>Quedan <b>{{ marks === 1 ? '1 marca' : `${marks} marcas` }} de texto provisional</b>. Se publicarían tal cual. <button type="button" class="font-medium underline underline-offset-2 max-md:min-h-11" @click="$emit('review')">Revisarlas</button></span>
      </p>
      <p v-if="def.key === 'privacy'" class="flex gap-2 text-adm-meta"><Info class="mt-0.5 size-4 flex-none" aria-hidden="true" />Si cambias cómo tratas los datos de los suscriptores, sube también la versión del texto de consentimiento en Ajustes › Newsletter.</p>
    </div>

    <p v-if="error" class="mt-4 flex gap-2 rounded-lg bg-adm-danger-soft p-3 text-[13px]" role="alert"><CircleAlert class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" />{{ error }}</p>
    <ul v-if="blockers.length" class="mt-4 space-y-1.5 rounded-lg bg-adm-danger-soft p-3 text-[13px]" role="alert">
      <li v-for="item in blockers" :key="item.key" class="flex gap-2"><CircleX class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" /><span>{{ item.hint ?? item.label }}<AdminEditorChecklistLinks :item="item" /></span></li>
    </ul>

    <template #footer>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnPrimary" :disabled="busy || blockers.length > 0" :aria-busy="busy || undefined" @click="$emit('publish')">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" /><Upload v-else aria-hidden="true" />{{ busy ? 'Publicando…' : 'Publicar' }}
      </button>
    </template>
  </AdminModal>
</template>
