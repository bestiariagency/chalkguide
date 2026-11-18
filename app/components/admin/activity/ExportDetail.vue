<script setup lang="ts">
import { Info, ShieldAlert } from 'lucide-vue-next'
import type { ActivityRecord } from '~/utils/admin-activity'
import { exportDetail } from '~/utils/admin-activity-export'

/** Drawer (bottom sheet under 768) with what an export asked for. The log keeps the query, never the file or the data. */
const props = defineProps<{ entry: ActivityRecord | undefined }>()
const emit = defineEmits<{ close: [] }>()
const open = computed({ get: () => !!props.entry, set: (v) => !v && emit('close') })
// Keeps the content while the drawer animates out.
const shown = ref<ActivityRecord>()
watch(() => props.entry, (e) => e && (shown.value = e), { immediate: true })
const authorName = useNoteAuthorName()
const detail = computed(() => (shown.value ? exportDetail(shown.value) : undefined))
</script>

<template>
  <AdminModal v-model:open="open" placement="right" :title="detail ? `Exportación de ${detail.what.toLowerCase()}` : 'Exportación'">
    <div v-if="detail && shown" class="space-y-4 text-sm">
      <dl class="grid grid-cols-[110px_1fr] gap-x-3 gap-y-2">
        <dt class="text-adm-meta">Quién</dt><dd>{{ authorName ?? 'Administrador del panel' }}</dd>
        <dt class="text-adm-meta">Cuándo</dt><dd class="tabular-nums">{{ adminDateTime(shown.occurredAt) }}</dd>
        <dt class="text-adm-meta">Qué</dt><dd>{{ detail.what }}</dd>
        <dt class="text-adm-meta">Filtros</dt>
        <dd>{{ detail.filters.length ? detail.filters.join(' · ') : 'Sin filtros' }}</dd>
        <template v-if="detail.columns"><dt class="text-adm-meta">Columnas</dt><dd class="break-words">{{ detail.columns }}</dd></template>
        <dt class="text-adm-meta">Filas</dt><dd class="tabular-nums">{{ detail.rows }}</dd>
        <dt class="text-adm-meta">Formato</dt><dd>{{ detail.format }}</dd>
        <template v-if="detail.purpose"><dt class="text-adm-meta">Para qué</dt><dd>{{ detail.purpose }}</dd></template>
      </dl>
      <p v-if="detail.personal" :class="[admChip, 'h-auto! bg-adm-warn-soft py-1 text-adm-warn']"><ShieldAlert aria-hidden="true" />Datos personales</p>
      <p :class="[admCard, 'flex items-start gap-2 bg-adm-subtle px-3 py-2 text-[13px] leading-5']" role="note">
        <Info class="mt-0.5 size-4 flex-none" aria-hidden="true" />
        <span>El registro guarda la consulta, no el archivo. Así puedes demostrar, para el RGPD, quién accedió a qué datos personales y cuándo.</span>
      </p>
    </div>
  </AdminModal>
</template>
