<script setup lang="ts">
import type { AdminNews } from '~/utils/admin-news'

/** Withdraw a published item: it leaves /noticias in a few minutes and goes back to Por revisar, losing nothing. Not dangerous: no red button. */
defineProps<{ news: AdminNews; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [] }>()
</script>

<template>
  <AdminModal v-model:open="open" alert stacked :busy="busy" :title="`¿Retirar «${news.titleEs}»?`" description="Dejará de verse en /noticias en unos minutos y volverá a Por revisar. No se pierde nada.">
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnPrimary" :disabled="busy" @click="emit('confirm')">Retirar</button>
    </template>
  </AdminModal>
</template>
