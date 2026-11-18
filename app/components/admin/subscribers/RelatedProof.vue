<script setup lang="ts">
import { ChevronRight, Info } from 'lucide-vue-next'
import { fullDateTime, fullDay } from '~/utils/admin-madrid'
import { sourceLabel, viaLabel, reasonShort, type SubscriberDetail } from '~/utils/admin-subscribers'

/**
 * Ficha section for the related-products consent (D66, README §18.3): same proof box as the newsletter's. Independent
 * of it. With `none` it is one line (and says that signing in does not count: rule 8); with `withdrawn`, a banner.
 */
const props = defineProps<{ detail: SubscriberDetail }>()
const s = computed(() => props.detail.subscriber)
const r = computed(() => s.value.related)
const accepted = computed(() => props.detail.relatedTexts[r.value.version ?? 0])
const sawEnglish = computed(() => s.value.locale === 'en' && !!accepted.value?.en)
const quote = computed(() => (sawEnglish.value ? accepted.value?.en : accepted.value?.es))
const dt = 'text-adm-meta'
// Events come newest first: the first related withdrawal is the current one.
const withdrawReason = computed(() => reasonShort(props.detail.events.find((e) => e.purpose === 'related_products' && e.event === 'unsubscribe')?.reason ?? null))
const newsletterOn = computed(() => s.value.status === 'active')
</script>

<template>
  <section aria-labelledby="sub-related-h">
    <div class="mb-2 flex flex-wrap items-center gap-2">
      <h3 id="sub-related-h" class="text-xs font-medium text-adm-meta">Avisos de Chalk app y productos afines</h3>
      <AdminSubscribersRelatedChip v-if="r.status !== 'none'" :status="r.status" />
    </div>

    <p v-if="r.status === 'none'" class="text-adm-meta">No los ha dado. Solo los da con la casilla del formulario o desde sus preferencias; iniciar sesión no cuenta.</p>

    <template v-else>
      <p v-if="r.status === 'withdrawn'" :class="[admCard, 'mb-2 flex items-start gap-2 bg-adm-subtle px-3 py-2 text-[13px] leading-5']">
        <Info class="mt-0.5 size-4 flex-none" aria-hidden="true" />
        <span>No recibe avisos afines. Solo esta persona puede volver a darlos, desde sus preferencias.<template v-if="newsletterOn"> La newsletter sigue activa.</template></span>
      </p>
      <div class="rounded-lg border border-adm-line bg-adm-side">
        <dl class="grid grid-cols-[128px_minmax(0,1fr)] gap-x-3 gap-y-2 p-3 max-[389px]:grid-cols-1 max-[389px]:gap-y-0.5 [&>dd]:min-w-0 max-[389px]:[&>dd]:mb-2">
          <dt :class="dt">Cuándo</dt>
          <dd class="tabular-nums">{{ r.consentAt ? fullDateTime(r.consentAt) : '—' }}<span class="block text-xs text-adm-meta">hora de Barcelona</span></dd>

          <dt :class="dt">Desde dónde</dt>
          <dd>
            {{ r.source ? sourceLabel(r.source) : '—' }}
            <span v-if="r.source === 'preferences'" class="block text-xs text-adm-meta">con el enlace de sus emails, sin login</span>
            <a v-else-if="s.consentPage && r.source !== 'chalk_waitlist'" :href="s.consentPage" target="_blank" rel="noopener" class="block font-mono text-xs break-all text-adm-meta underline underline-offset-2 hover:text-adm-fg">{{ s.consentPage }}<span class="sr-only"> (se abre en otra pestaña)</span></a>
          </dd>

          <dt :class="dt">Texto aceptado</dt>
          <dd>
            Versión {{ r.version ?? '—' }} · <span class="font-mono text-xs uppercase">{{ sawEnglish ? 'en' : 'es' }}</span>
            <details class="group mt-1">
              <summary class="inline-flex min-h-8 max-md:min-h-11 cursor-pointer list-none items-center gap-1 text-adm-meta underline decoration-adm-line-strong underline-offset-2 hover:text-adm-fg">
                <ChevronRight class="size-3.5 transition-transform group-open:rotate-90" aria-hidden="true" />Ver el texto exacto
              </summary>
              <template v-if="accepted && accepted.preserved && quote">
                <blockquote class="mt-1 border-l-2 border-adm-line-strong py-1.5 pl-3" :lang="sawEnglish ? 'en' : 'es'">{{ quote }}</blockquote>
                <p class="mt-1 text-xs text-adm-meta">Vigente del {{ accepted.validFrom ? fullDay(accepted.validFrom) : '—' }}{{ accepted.validTo ? ` al ${fullDay(accepted.validTo)}` : ' hasta hoy' }}.</p>
              </template>
              <p v-else class="mt-1 text-xs text-adm-meta">El texto de esta versión no se conservó.</p>
            </details>
          </dd>

          <dt :class="dt">Estado</dt>
          <dd v-if="r.status === 'pending'">Pendiente: se activa si confirma el email; si caduca, se descarta.</dd>
          <dd v-else-if="r.confirmedAt">Vigente desde {{ fullDateTime(r.confirmedAt) }} · {{ r.source === 'preferences' ? 'desde sus preferencias' : 'con el doble opt-in' }}</dd>
          <dd v-else class="text-adm-muted">—</dd>

          <dt :class="dt">Retirada</dt>
          <dd v-if="r.withdrawnAt"><span class="tabular-nums">{{ fullDateTime(r.withdrawnAt) }}</span><span class="block text-xs text-adm-meta">{{ viaLabel(r.withdrawSource) }}<template v-if="withdrawReason"> · «{{ withdrawReason }}»</template></span></dd>
          <dd v-else class="text-adm-muted">—</dd>
        </dl>
      </div>
    </template>
    <p class="mt-2 text-xs text-adm-meta">Independiente de la newsletter: dar de baja no la retira, y retirarla no da de baja.</p>
  </section>
</template>
