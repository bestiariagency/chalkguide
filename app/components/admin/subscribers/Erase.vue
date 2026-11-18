<script setup lang="ts">
import { Check, Loader2, Minus, Trash2, TriangleAlert } from 'lucide-vue-next'
import { ERASE_REASONS, type Subscriber } from '~/utils/admin-subscribers'

/**
 * Suprimir datos (RGPD art. 17), one by one and different from unsubscribing: the email is erased, the anonymous
 * history stays. Level 4 confirmation: a reason and the exact email typed (case and edge spaces ignored). In any state.
 */
const props = defineProps<{ subscriber: Subscriber; busy: boolean; mismatch: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [typed: string, reason: string] }>()

const reason = ref<string>()
const typed = ref('')
const matches = computed(() => typed.value.trim().toLowerCase() === props.subscriber.email)
const can = computed(() => !!reason.value && matches.value && !props.busy)
const typedId = `sub-erase-${useId()}`
const helpId = `${typedId}-help`
function submit() {
  if (can.value && reason.value) emit('confirm', typed.value, reason.value)
}
</script>

<template>
  <AdminModal v-model:open="open" alert stacked :busy="busy" size="md" title="¿Suprimir los datos?">
    <template #title><span class="break-words">¿Suprimir los datos de <span class="font-mono text-sm break-all">{{ subscriber.email }}</span>?</span></template>
    <div class="space-y-4 text-sm">
      <p class="text-adm-meta">Es el derecho de supresión del RGPD (art. 17). <b class="text-adm-fg">No se puede deshacer.</b> Si solo quiere dejar de recibir emails, usa «Dar de baja»: así se conserva la prueba de que se respetó su decisión.</p>
      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <p class="mb-1 text-xs font-medium text-adm-meta">Se borra</p>
          <ul class="space-y-1">
            <li class="flex gap-1.5"><Minus class="mt-[3px] size-3.5 flex-none text-adm-danger" aria-hidden="true" />El email</li>
            <li class="flex gap-1.5"><Minus class="mt-[3px] size-3.5 flex-none text-adm-danger" aria-hidden="true" />El vínculo con su cuenta</li>
            <li class="flex gap-1.5"><Minus class="mt-[3px] size-3.5 flex-none text-adm-danger" aria-hidden="true" />La página exacta del alta y el enlace de baja</li>
          </ul>
        </div>
        <div>
          <p class="mb-1 text-xs font-medium text-adm-meta">Se queda, sin email</p>
          <ul class="space-y-1">
            <li class="flex gap-1.5"><Check class="mt-[3px] size-3.5 flex-none text-adm-meta" aria-hidden="true" />Un historial anónimo: fechas, origen y versión del texto (para las cifras)</li>
            <li class="flex gap-1.5"><Check class="mt-[3px] size-3.5 flex-none text-adm-meta" aria-hidden="true" />Su cuenta de ChalkGuide y Chalk app, si tiene: no se toca</li>
          </ul>
        </div>
      </div>
      <p class="flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5 text-adm-warn"><TriangleAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" /><span>Si exportaste suscriptores antes, borra también esos archivos. <span class="opacity-80">Cuando se conecte el proveedor de email, habrá que borrarlo también allí.</span></span></p>
      <fieldset>
        <legend :class="admLabel">Motivo <span class="text-adm-danger" aria-hidden="true">*</span><span class="sr-only">(obligatorio)</span></legend>
        <div class="space-y-1">
          <label v-for="r in ERASE_REASONS" :key="r.value" class="flex min-h-8 cursor-pointer items-center gap-2 max-md:min-h-11">
            <input v-model="reason" type="radio" name="erase-reason" :value="r.value" class="size-4 accent-adm-acc" :disabled="busy" />{{ r.label }}
          </label>
        </div>
      </fieldset>
      <div>
        <label :for="typedId" :class="admLabel">Escribe el email para confirmar</label>
        <input :id="typedId" v-model="typed" :class="[admInput, 'font-mono', mismatch && admInputInvalid]" :placeholder="subscriber.email" autocomplete="off" autocapitalize="off" spellcheck="false" :aria-describedby="helpId" :aria-invalid="mismatch || undefined" @keydown.enter.prevent="submit" />
        <p :id="helpId" :class="['mt-1 text-xs', mismatch ? 'text-adm-danger' : 'text-adm-meta']" :role="mismatch ? 'alert' : undefined">{{ mismatch ? 'No coincide con el email del suscriptor. Revísalo.' : 'Tiene que coincidir exactamente.' }}</p>
      </div>
    </div>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnDanger" :disabled="!can" :aria-busy="busy || undefined" @click="submit">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" /><Trash2 v-else aria-hidden="true" />Suprimir para siempre
      </button>
    </template>
  </AdminModal>
</template>
