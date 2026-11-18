<script setup lang="ts">
import { CircleAlert, CircleCheck, CircleX, Loader2, TriangleAlert, Upload } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'
import type { ChangeEntry } from '~/utils/article-changes'
import type { ChecklistItem } from '~/utils/article-form'

/**
 * "Publicar cambios" (D23): one row per changed field in plain language, "Revertir" per field,
 * the publish checklist and, on `PT409`, the choice between publishing anyway and reloading.
 */
const props = withDefaults(defineProps<{
  entries: ChangeEntry[]
  checklist: ChecklistItem[]
  mediaOf: (id: string | null) => AdminMedia | null
  busy: boolean
  conflict: boolean
  error: string
  /** Replaces the default subtitle (pages explain the real delay before the site shows the change). */
  description?: string
}>(), { description: 'Frente a la versión publicada. Revisa y publica: los cambios salen al sitio al momento.' })
defineEmits<{ revert: [key: string]; publish: []; force: []; discard: []; reload: [] }>()
const open = defineModel<boolean>('open', { default: false })

const blockers = computed(() => props.checklist.filter((i) => i.blocking && !i.ok))
const passed = computed(() => props.checklist.filter((i) => i.ok).length)
const count = computed(() => props.entries.length)
// Reverting the last change leaves nothing to publish: close.
watch(count, (value) => value === 0 && open.value && (open.value = false))
</script>

<template>
  <AdminModal
    v-model:open="open"
    size="md"
    :busy="busy"
    :title="`Publicar ${count} ${count === 1 ? 'cambio' : 'cambios'}`"
    :description="description"
  >
    <ul class="divide-y divide-adm-line rounded-lg border border-adm-line text-sm" aria-label="Cambios sin publicar">
      <AdminEditorChangeRow v-for="entry in entries" :key="entry.key" :entry="entry" :media-of="mediaOf" :busy="busy" @revert="$emit('revert', $event)" />
    </ul>

    <slot name="extra" />

    <div v-if="conflict" class="mt-4 rounded-lg bg-adm-warn-soft p-3 text-[13px]" role="alert">
      <p class="flex gap-2 font-medium text-adm-warn"><TriangleAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" />Lo publicado cambió mientras editabas.</p>
      <p class="mt-1 pl-6">Si publicas igualmente, tus cambios se aplican sobre la versión nueva y pueden pisar lo que se cambió. También puedes recargar para ver la versión actual con tu borrador encima.</p>
      <p class="mt-2 flex flex-wrap gap-2 pl-6">
        <button type="button" :class="admBtnRev" :disabled="busy || blockers.length > 0" @click="$emit('force')">Publicar igualmente</button>
        <button type="button" :class="admBtnGhost" :disabled="busy" @click="$emit('reload')">Recargar</button>
      </p>
    </div>
    <p v-else-if="error" class="mt-4 flex gap-2 rounded-lg bg-adm-danger-soft p-3 text-[13px]" role="alert"><CircleAlert class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" />{{ error }}</p>

    <ul v-if="blockers.length" class="mt-4 space-y-1.5 rounded-lg bg-adm-danger-soft p-3 text-[13px]" role="alert">
      <li v-for="item in blockers" :key="item.key" class="flex gap-2"><CircleX class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" /><span>{{ item.hint ?? item.label }}<AdminEditorChecklistLinks :item="item" /></span></li>
    </ul>
    <p v-else class="mt-4 flex items-center gap-2 text-sm"><CircleCheck class="size-4 text-adm-ok" aria-hidden="true" />Listo para publicar · {{ passed }} de {{ checklist.length }} comprobaciones</p>

    <template #footer>
      <button type="button" :class="[admBtnQuiet, 'mr-auto text-adm-danger! max-md:order-last']" :disabled="busy" @click="$emit('discard')">Descartar todos…</button>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Seguir editando</button>
      <button v-if="!conflict" type="button" :class="admBtnRev" :disabled="busy || blockers.length > 0 || !count" :aria-busy="busy || undefined" @click="$emit('publish')">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" /><Upload v-else aria-hidden="true" />{{ busy ? 'Publicando…' : 'Publicar cambios' }}
      </button>
    </template>
  </AdminModal>
</template>
