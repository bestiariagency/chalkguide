<script setup lang="ts">
import { BadgeCheck, ChevronRight, Copy } from 'lucide-vue-next'
import { localeName, SENDING_CONNECTED, sourceLabel, reasonShort, viaLabel, type SubscriberDetail } from '~/utils/admin-subscribers'
import { agoLabel, fullDateTime, fullDay } from '~/utils/admin-madrid'

/**
 * Prueba de consentimiento (read only): when, from where, the exact text accepted, double opt-in, unsubscription,
 * language and account. Having an account is NOT consent (rule 8): it is shown as a separate fact with that warning.
 */
const props = defineProps<{ detail: SubscriberDetail }>()
const emit = defineEmits<{ copy: [] }>()
const s = computed(() => props.detail.subscriber)
const accepted = computed(() => props.detail.texts[s.value.version])
const sawEnglish = computed(() => s.value.locale === 'en' && !!accepted.value?.en)
const quote = computed(() => (sawEnglish.value ? accepted.value?.en : accepted.value?.es))
const dt = 'text-adm-meta'
</script>

<template>
  <section aria-labelledby="sub-proof-h">
    <div class="mb-2 flex items-center gap-2">
      <h3 id="sub-proof-h" class="text-xs font-medium text-adm-meta">Prueba de consentimiento</h3>
      <button type="button" :class="[admBtnQuiet, 'ml-auto h-7! px-2 max-md:h-11! text-xs']" @click="emit('copy')"><Copy aria-hidden="true" />Copiar como texto</button>
    </div>
    <div class="rounded-lg border border-adm-line bg-adm-side">
      <dl class="grid grid-cols-[128px_minmax(0,1fr)] gap-x-3 gap-y-2 p-3 max-[389px]:grid-cols-1 max-[389px]:gap-y-0.5 [&>dd]:min-w-0 max-[389px]:[&>dd]:mb-2">
        <dt :class="dt">Cuándo</dt>
        <dd class="tabular-nums">{{ fullDateTime(s.consentAt) }}<span class="block text-xs text-adm-meta">hora de Barcelona</span></dd>

        <dt :class="dt">Desde dónde</dt>
        <dd>
          {{ sourceLabel(s.source) }}
          <a v-if="s.consentPage" :href="s.consentPage" target="_blank" rel="noopener" class="block font-mono text-xs break-all text-adm-meta underline underline-offset-2 hover:text-adm-fg">{{ s.consentPage }}<span class="sr-only"> (se abre en otra pestaña)</span></a>
        </dd>

        <dt :class="dt">Texto aceptado</dt>
        <dd>
          Versión {{ s.version }} · <span class="font-mono text-xs uppercase">{{ sawEnglish ? 'en' : 'es' }}</span>
          <details class="group mt-1">
            <summary class="inline-flex min-h-8 max-md:min-h-11 cursor-pointer list-none items-center gap-1 text-adm-meta underline decoration-adm-line-strong underline-offset-2 hover:text-adm-fg">
              <ChevronRight class="size-3.5 transition-transform group-open:rotate-90" aria-hidden="true" />Ver el texto exacto
            </summary>
            <template v-if="accepted && accepted.preserved && quote">
              <blockquote class="mt-1 border-l-2 border-adm-line-strong py-1.5 pl-3" :lang="sawEnglish ? 'en' : 'es'">{{ quote }}</blockquote>
              <p class="mt-1 text-xs text-adm-meta">
                Vigente del {{ accepted.validFrom ? fullDay(accepted.validFrom) : '—' }}{{ accepted.validTo ? ` al ${fullDay(accepted.validTo)}` : ' hasta hoy' }}.
                <template v-if="s.locale === 'en' && !accepted.en"> En esa versión no había texto en inglés: vio el español.</template>
              </p>
            </template>
            <p v-else class="mt-1 text-xs text-adm-meta">El texto de esta versión no se conservó.</p>
          </details>
        </dd>

        <dt :class="dt">Doble opt-in</dt>
        <dd v-if="s.confirmedAt"><span class="inline-flex items-center gap-1 font-medium text-adm-st-pub"><BadgeCheck class="size-3.5" aria-hidden="true" />Confirmado</span> <span class="tabular-nums">{{ fullDateTime(s.confirmedAt) }}</span></dd>
        <dd v-else-if="s.status === 'expired'"><span class="font-medium">Caducado</span> sin confirmar<span v-if="s.anonymizeAt" class="text-adm-meta"> · se anonimiza el {{ fullDay(s.anonymizeAt) }}</span></dd>
        <dd v-else-if="s.status === 'pending'">
          <span class="font-medium text-adm-warn">Sin confirmar</span>
          <span v-if="!SENDING_CONNECTED" class="text-adm-meta"> · el email de confirmación aún no se envía (F4.6)</span>
          <span v-else class="text-adm-meta"> · enviado {{ agoLabel(s.consentAt) }}<template v-if="s.expiresAt"> · caduca el {{ fullDay(s.expiresAt) }}</template></span>
        </dd>
        <dd v-else class="text-adm-muted">Nunca confirmó</dd>

        <dt :class="dt">Baja</dt>
        <dd v-if="s.unsubscribedAt"><span class="tabular-nums">{{ fullDateTime(s.unsubscribedAt) }}</span><span class="block text-xs text-adm-meta">{{ viaLabel(s.unsubscribeSource) }}<template v-if="s.unsubscribeReason"> · «{{ reasonShort(s.unsubscribeReason) }}»</template></span></dd>
        <dd v-else class="text-adm-muted">—</dd>

        <dt :class="dt">Idioma</dt>
        <dd>{{ localeName(s.locale) }}</dd>

        <dt :class="dt">Cuenta</dt>
        <dd v-if="s.hasAccount">Tiene cuenta (Google)<span class="block text-xs text-adm-meta">Iniciar sesión no es consentimiento: lo que vale es la casilla que marcó al suscribirse.</span></dd>
        <dd v-else class="text-adm-muted">Sin cuenta</dd>
      </dl>
    </div>
    <p class="mt-2 text-xs text-adm-meta">No se guardan IP ni navegador.</p>
  </section>
</template>
