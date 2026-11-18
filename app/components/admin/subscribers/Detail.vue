<script setup lang="ts">
import { Hourglass, MegaphoneOff, Plug, Trash2, UserX } from 'lucide-vue-next'
import { proofText } from '~/utils/admin-subscriber-detail'
import { canUnsubscribe, type Subscriber } from '~/utils/admin-subscribers'
import { canWithdrawRelated } from '~/utils/admin-subscribers-related'
import { fullDay } from '~/utils/admin-madrid'

/**
 * Ficha of a subscriber (drawer; bottom sheet under 768): read only. Banner by state, prueba de consentimiento,
 * historial (one timeline for both consents), provider (not connected yet) and the actions: Dar de baja…, Retirar afines… (D66) and
 * Suprimir datos…. Nothing is edited,
 * so there is no "Guardar".
 */
const props = defineProps<{ id: string | undefined }>()
const emit = defineEmits<{ close: []; unsubscribe: [subscriber: Subscriber]; withdraw: [subscriber: Subscriber]; erase: [subscriber: Subscriber]; copy: [text: string] }>()
const open = computed({ get: () => !!props.id, set: (v) => !v && emit('close') })
const { detail, status, errorCode, retry } = useAdminSubscriberDetail(computed(() => props.id))
const s = computed(() => detail.value?.subscriber)
defineExpose({ reload: retry })
const gone = computed(() => errorCode.value === 'P0002')
</script>

<template>
  <AdminModal v-model:open="open" placement="right" title="Suscriptor">
    <template #title><span class="block font-mono text-[13px] font-medium break-all">{{ s?.email ?? 'Suscriptor' }}</span></template>
    <div v-if="status === 'pending'" class="space-y-4" aria-busy="true">
      <span class="sr-only" role="status">Cargando el suscriptor…</span>
      <span class="block h-24 animate-pulse rounded-lg bg-adm-subtle motion-reduce:animate-none" /><span class="block h-40 animate-pulse rounded-lg bg-adm-subtle motion-reduce:animate-none" />
    </div>
    <AdminStateBlock v-else-if="status === 'error'" kind="error" :title="gone ? 'Este suscriptor ya no existe' : 'No se ha podido cargar la ficha'" :description="gone ? 'Quizá se suprimió desde otra pestaña.' : undefined" :code="gone ? undefined : errorCode" @retry="retry">
      <button v-if="gone" type="button" :class="admBtnGhost" @click="emit('close')">Cerrar</button>
    </AdminStateBlock>
    <div v-else-if="detail && s" class="space-y-6 text-sm">
      <p><AdminSubscribersChip :status="s.status" /></p>
      <p v-if="s.status === 'unsubscribed'" :class="[admCard, 'flex items-start gap-2 bg-adm-subtle px-3 py-2 text-[13px] leading-5']"><UserX class="mt-0.5 size-4 flex-none" aria-hidden="true" /><span>No recibe nada. Solo esta persona puede volver, con un alta nueva desde el sitio y su confirmación por email.</span></p>
      <p v-if="s.status === 'expired'" :class="[admCard, 'flex items-start gap-2 bg-adm-subtle px-3 py-2 text-[13px] leading-5']"><Hourglass class="mt-0.5 size-4 flex-none" aria-hidden="true" /><span>No confirmó en 7 días: nunca recibió la newsletter.<template v-if="s.anonymizeAt"> El email se anonimiza solo el {{ fullDay(s.anonymizeAt) }} (minimización de datos).</template></span></p>
      <AdminSubscribersProof :detail="detail" @copy="emit('copy', proofText(detail))" />
      <AdminSubscribersRelatedProof :detail="detail" />
      <AdminSubscribersHistory :events="detail.events" />
      <section aria-labelledby="sub-provider-h">
        <h3 id="sub-provider-h" class="mb-2 text-xs font-medium text-adm-meta">Proveedor de email</h3>
        <p class="flex items-start gap-1.5 text-adm-meta"><Plug class="mt-0.5 size-4 flex-none" aria-hidden="true" /><span>Sin conectar todavía (F4.6). Cuando lo esté, aquí verás si está sincronizado.</span></p>
      </section>
    </div>
    <template v-if="s" #footer>
      <button v-if="canUnsubscribe(s)" type="button" :class="admBtnGhost" @click="emit('unsubscribe', s)"><UserX aria-hidden="true" />Dar de baja…</button>
      <button v-if="canWithdrawRelated(s)" type="button" :class="admBtnGhost" @click="emit('withdraw', s)"><MegaphoneOff aria-hidden="true" />Retirar afines…</button>
      <button type="button" :class="[admBtnDangerGhost, (canUnsubscribe(s) || canWithdrawRelated(s)) && 'md:mr-0 md:ml-auto']" @click="emit('erase', s)"><Trash2 aria-hidden="true" />Suprimir datos…</button>
      <p class="w-full basis-full text-xs text-adm-meta max-md:flex-none!">{{ canUnsubscribe(s) || canWithdrawRelated(s) ? 'Dar de baja y retirar afines son independientes y no se deshacen desde el panel. Suprimir anonimiza el registro (RGPD).' : 'Suprimir anonimiza el registro (RGPD). No se puede deshacer.' }}</p>
    </template>
  </AdminModal>
</template>
