<script setup lang="ts">
import { TriangleAlert } from 'lucide-vue-next'
import type { AdminToken } from '~/utils/admin-ingest'

/** Revoke (alertdialog, focus on Cancelar). If it is the only active token the routine stops writing, and the health alert fires after 4 days. */
defineProps<{ token: AdminToken; onlyActive: boolean; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [] }>()
</script>

<template>
  <AdminModal v-model:open="open" alert :busy="busy" :title="`¿Revocar «${token.label}»?`">
    <div class="space-y-3 text-sm">
      <AdminBanner v-if="onlyActive" kind="warn" :icon="TriangleAlert">Es el único token activo. La rutina dejará de poder escribir hasta que pegues uno nuevo, y saltará la alerta de salud a los 4 días.</AdminBanner>
      <p>Se revoca al momento y no se puede deshacer. Los borradores ya creados no cambian.</p>
    </div>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnDanger" :disabled="busy" @click="emit('confirm')">Revocar</button>
    </template>
  </AdminModal>
</template>
