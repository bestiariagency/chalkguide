<script setup lang="ts">
import { History, Loader2, UserX } from 'lucide-vue-next'
import { UNSUBSCRIBE_REASONS, type Subscriber } from '~/utils/admin-subscribers'

/**
 * Dar de baja (alertdialog, focus on Cancelar), one or many. The reason is required and the button stays disabled
 * until one is chosen. It cannot be undone from the panel (only the person can come back). Not typed: it is
 * irreversible but it does not delete data. `skipped` = selected ones that cannot be unsubscribed (already out or expired).
 */
const props = defineProps<{ subscribers: readonly Subscriber[]; skipped?: number; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [reason: string] }>()

const reason = ref<string>()
const one = computed(() => props.subscribers.length === 1)
const title = computed(() => (one.value ? `¿Dar de baja a ${props.subscribers[0]?.email}?` : `¿Dar de baja a ${props.subscribers.length} suscriptores?`))
const shown = computed(() => props.subscribers.slice(0, 5))
</script>

<template>
  <AdminModal v-model:open="open" alert stacked :busy="busy" :title="title">
    <template #title><span class="break-words">{{ one ? '¿Dar de baja a ' : title }}<span v-if="one" class="font-mono text-sm break-all">{{ subscribers[0]?.email }}</span>{{ one ? '?' : '' }}</span></template>
    <div class="space-y-4">
      <p class="text-sm text-adm-meta">
        {{ one ? 'Quedará' : 'Quedarán' }} de baja de la newsletter. <b class="text-adm-fg">Desde el panel no se puede deshacer:</b> solo {{ one ? 'esa persona puede' : 'cada persona puede' }} volver a suscribirse, con un alta nueva y su confirmación por email.
      </p>
      <ul v-if="!one" class="space-y-1 font-mono text-[13px]" aria-label="Suscriptores a dar de baja">
        <li v-for="s in shown" :key="s.id" class="truncate">{{ s.email }}</li>
        <li v-if="subscribers.length > shown.length" class="font-sans text-adm-meta">y {{ subscribers.length - shown.length }} más</li>
      </ul>
      <p v-if="skipped" class="rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5 text-adm-warn" role="status">
        {{ skipped === 1 ? 'Se deja fuera 1 seleccionado que no se puede dar de baja (ya está de baja o ha caducado).' : `Se dejan fuera ${skipped} seleccionados que no se pueden dar de baja (ya están de baja o han caducado).` }}
      </p>
      <fieldset>
        <legend :class="admLabel">Motivo <span class="text-adm-danger" aria-hidden="true">*</span><span class="sr-only">(obligatorio)</span></legend>
        <div class="space-y-1 text-sm">
          <label v-for="r in UNSUBSCRIBE_REASONS" :key="r.value" class="flex min-h-8 cursor-pointer items-center gap-2 max-md:min-h-11">
            <input v-model="reason" type="radio" name="unsubscribe-reason" :value="r.value" class="size-4 accent-adm-acc" :disabled="busy" />{{ r.label }}
          </label>
        </div>
      </fieldset>
      <p class="flex items-start gap-1.5 text-xs text-adm-meta"><History class="mt-px size-3.5 flex-none" aria-hidden="true" />Queda en su historial: fecha, «desde el panel» y el motivo. La prueba de consentimiento se conserva.</p>
    </div>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnDanger" :disabled="!reason || busy" :aria-busy="busy || undefined" @click="reason && emit('confirm', reason)">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" /><UserX v-else aria-hidden="true" />{{ busy ? 'Dando de baja…' : one ? 'Dar de baja' : `Dar de baja a ${subscribers.length}` }}
      </button>
    </template>
  </AdminModal>
</template>
