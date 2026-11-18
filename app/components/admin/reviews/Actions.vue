<script setup lang="ts">
import { Check, Eye, EyeOff, Image } from 'lucide-vue-next'
import type { ReviewStatus } from '~/utils/admin-reviews'

/** Moderation buttons: hidden ones can be shown again; visible ones are approved (next) or hidden. */
defineProps<{ status: ReviewStatus; busy: boolean; pendingPhotos?: number }>()
const emit = defineEmits<{ hide: []; show: []; approve: []; approvePhotos: [] }>()
</script>

<template>
  <div class="flex flex-wrap gap-2 max-lg:[&>*]:flex-1">
    <button v-if="status === 'hidden'" type="button" :class="admBtnPrimary" :disabled="busy" @click="emit('show')"><Eye aria-hidden="true" />Mostrar de nuevo</button>
    <template v-else>
      <button v-if="pendingPhotos" type="button" :class="admBtnPrimary" :disabled="busy" @click="emit('approvePhotos')"><Image aria-hidden="true" />Aprobar fotos y siguiente <span class="rounded border border-white/30 px-1 font-mono text-[11px] leading-4 text-white/70 max-lg:hidden">A</span></button>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="emit('approve')"><Check aria-hidden="true" />Está bien, siguiente <span :class="[admKbd, 'max-lg:hidden']">V</span></button>
      <button v-if="pendingPhotos" type="button" :class="admBtnGhost" :disabled="busy" @click="emit('hide')"><EyeOff aria-hidden="true" />Ocultar opinión <span :class="[admKbd, 'max-lg:hidden']">H</span></button>
      <button v-else type="button" :class="admBtnPrimary" :disabled="busy" @click="emit('hide')"><EyeOff aria-hidden="true" />Ocultar <span class="rounded border border-white/30 px-1 font-mono text-[11px] leading-4 text-white/70 max-lg:hidden">H</span></button>
    </template>
  </div>
</template>
