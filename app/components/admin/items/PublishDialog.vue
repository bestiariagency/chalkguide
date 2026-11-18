<script setup lang="ts">
import { CircleAlert, CircleCheck, CircleX, Loader2, TriangleAlert, Upload } from 'lucide-vue-next'
import type { ChecklistItem } from '~/utils/article-form'

/** "Publicar" an unpublished item: the checklist (blocking items stop it), and the server's refusal if any. */
const props = defineProps<{ checklist: ChecklistItem[]; busy: boolean; error: string; name: string }>()
defineEmits<{ confirm: [] }>()
const open = defineModel<boolean>('open', { default: false })
const blockers = computed(() => props.checklist.filter((i) => i.blocking && !i.ok))
const advice = computed(() => props.checklist.filter((i) => !i.blocking && !i.ok))
</script>

<template>
  <AdminModal v-model:open="open" :busy="busy" :title="`Publicar «${name || 'Sin nombre'}»`" description="La ficha se verá en el sitio al momento.">
    <ul v-if="blockers.length" class="space-y-1.5 rounded-lg bg-adm-danger-soft p-3 text-[13px]" role="alert">
      <li v-for="item in blockers" :key="item.key" class="flex gap-2"><CircleX class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" /><span>{{ item.hint ?? item.label }}<AdminEditorChecklistLinks :item="item" /></span></li>
    </ul>
    <p v-else class="flex items-center gap-2 text-sm"><CircleCheck class="size-4 text-adm-ok" aria-hidden="true" />Nada bloquea la publicación.</p>
    <div v-if="advice.length" class="mt-4 rounded-lg bg-adm-warn-soft p-3 text-[13px]">
      <p class="font-medium text-adm-warn">Avisos (no bloquean)</p>
      <ul class="mt-1.5 space-y-1.5">
        <li v-for="item in advice" :key="item.key" class="flex gap-2"><TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />{{ item.label }}<template v-if="item.hint"> · {{ item.hint }}</template></li>
      </ul>
    </div>
    <p v-if="error" class="mt-4 flex gap-2 rounded-lg bg-adm-danger-soft p-3 text-[13px]" role="alert"><CircleAlert class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" />{{ error }}</p>
    <template #footer>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Seguir editando</button>
      <button type="button" :class="admBtnPrimary" :disabled="busy || blockers.length > 0" :aria-busy="busy || undefined" @click="$emit('confirm')">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" /><Upload v-else aria-hidden="true" />{{ busy ? 'Publicando…' : 'Publicar' }}
      </button>
    </template>
  </AdminModal>
</template>
