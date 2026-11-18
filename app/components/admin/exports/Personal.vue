<script setup lang="ts">
import { MailX, ShieldAlert } from 'lucide-vue-next'
import { PURPOSES } from '~/utils/admin-export'

/** Subscribers only (D37, README §12.3): warning, mandatory purpose and the explicit confirmation. */
const props = defineProps<{ rows: number; status: string }>()
const purpose = defineModel<string>('purpose', { required: true })
const confirmed = defineModel<boolean>('confirmed', { required: true })

const scope = computed(
  () =>
    ({
      unsubscribed: props.rows === 1 ? 'Es una baja: esta persona ya no quiere recibir nada.' : `Son ${fmtInt(props.rows)} bajas: personas que ya no quieren recibir nada.`,
      pending: 'No han confirmado su email, así que no nos han dado permiso para escribirles.',
      all: 'Incluye bajas y suscriptores sin confirmar.',
    })[props.status],
)
</script>

<template>
  <div class="space-y-3">
    <p class="flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5 text-adm-warn">
      <ShieldAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" />
      <span><b>Contiene {{ countOf(rows, 'email', 'emails') }}.</b> Guárdalo en un sitio seguro, no lo compartas y bórralo cuando ya no lo necesites. Si más adelante suprimes a alguien, bórralo también de este archivo.</span>
    </p>
    <p v-if="scope" class="flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5 text-adm-warn">
      <MailX class="mt-0.5 size-4 flex-none" aria-hidden="true" />
      <span><b>{{ scope }}</b> No subas este archivo a ninguna herramienta de envío.</span>
    </p>
    <div>
      <label for="ex-purpose" :class="admLabel">Para qué lo exportas <span class="text-adm-danger" aria-hidden="true">*</span><span class="sr-only">(obligatorio)</span></label>
      <select id="ex-purpose" v-model="purpose" required :class="[admInput, 'pr-8']">
        <option value="" disabled>Elige una finalidad</option>
        <option v-for="p in PURPOSES" :key="p.value" :value="p.value">{{ p.label }}</option>
      </select>
      <p class="mt-1 text-xs text-adm-meta">Queda en Actividad junto a la exportación.</p>
    </div>
    <label class="flex min-h-8 cursor-pointer items-start gap-2 text-[13px] leading-5 max-md:min-h-11">
      <input v-model="confirmed" type="checkbox" class="mt-0.5 size-4 flex-none accent-adm-acc" />Entiendo que el archivo tiene datos personales y que soy responsable de guardarlo y borrarlo.
    </label>
  </div>
</template>
