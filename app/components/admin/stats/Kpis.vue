<script setup lang="ts">
import { sumCategories, type StatsData } from '~/utils/admin-stats'
import { fmtDay, fmtNum } from '~/utils/admin-stats-format'
import { statsPeriodText } from '~/utils/admin-stats-text'

/**
 * The four KPIs (README §16.3): not links (here you look, in Inicio you navigate). The numbers come from
 * `current_totals`, never from summing periods. The comparison line comes from `previous`.
 */
const props = defineProps<{ data: StatsData; today: string; describedby?: string }>()

const t = computed(() => props.data.totals)
const p = computed(() => props.data.previous)
const per = computed(() => statsPeriodText(props.data.range))
const net = computed(() => t.value.subsIn - t.value.subsOut)
const reviews = computed(() => t.value.reviewsVisible + t.value.reviewsHidden)
const prevReviews = computed(() => (p.value ? p.value.reviewsVisible + p.value.reviewsHidden : null))
const itemsTotal = computed(() => sumCategories(props.data.itemsAtEnd))
const itemsNew = computed(() => sumCategories(t.value.itemsNew))
const types = computed(() => Object.values(props.data.itemsAtEnd).filter((n) => n > 0).length)
/** «al 15 jun» when the range ends before today: the subscribers and published-items totals are at that day. */
const past = computed(() => (props.data.to < props.today ? `al ${fmtDay(props.data.to, false)}` : ''))
const hiddenPercent = computed(() => (reviews.value ? Math.round((t.value.reviewsHidden / reviews.value) * 100) : 0))

const tile = 'p-4 border-r border-b border-adm-line max-lg:[&:nth-child(2n)]:border-r-0 max-lg:[&:nth-child(n+3)]:border-b-0 lg:border-b-0 lg:[&:last-child]:border-r-0'
const label = 'text-xs text-adm-meta'
const value = 'mt-1 text-2xl font-semibold tracking-tight tabular-nums'
const unit = 'text-sm font-normal text-adm-meta'
const sub = 'mt-1 text-xs leading-4 text-adm-meta tabular-nums'
</script>

<template>
  <section aria-label="Resumen del periodo" :aria-describedby="describedby" class="grid grid-cols-2 overflow-hidden rounded-lg border border-adm-line bg-adm-elev lg:grid-cols-4">
    <div :class="tile">
      <p :class="label">Suscriptores activos</p>
      <p :class="value">{{ fmtNum(t.subsTotalEnd) }} <span v-if="past" :class="unit">{{ past }}</span></p>
      <p :class="sub">
        <template v-if="t.subsTotalEnd || t.subsIn">
          <span :class="net > 0 ? 'font-medium text-adm-ok' : 'text-adm-meta'">{{ net > 0 ? '+' : net < 0 ? '−' : '' }}{{ fmtNum(Math.abs(net)) }}</span> {{ per }}
          <span class="block">{{ fmtNum(t.subsIn) }} {{ t.subsIn === 1 ? 'alta' : 'altas' }} · {{ fmtNum(t.subsOut) }} {{ t.subsOut === 1 ? 'baja' : 'bajas' }}</span>
        </template>
        <template v-else>Sin altas todavía</template>
      </p>
      <AdminStatsDelta :current="t.subsIn" :previous="p?.subsIn ?? null" :noun="['alta', 'altas']" />
    </div>
    <div :class="tile">
      <p :class="label">Artículos publicados</p>
      <p :class="value">{{ fmtNum(t.articles) }} <span :class="unit">{{ per }}</span></p>
      <p :class="sub">{{ fmtNum(data.articlesTotal) }} {{ data.articlesTotal === 1 ? 'publicado' : 'publicados' }} en total</p>
      <AdminStatsDelta :current="t.articles" :previous="p?.articles ?? null" />
    </div>
    <div :class="tile">
      <p :class="label">Opiniones recibidas</p>
      <p :class="value">{{ fmtNum(reviews) }} <span :class="unit">{{ per }}</span></p>
      <p :class="sub">{{ reviews ? `${fmtNum(t.reviewsHidden)} ${t.reviewsHidden === 1 ? 'oculta' : 'ocultas'} (${hiddenPercent} %)` : 'Ninguna todavía' }}</p>
      <AdminStatsDelta :current="reviews" :previous="prevReviews" />
    </div>
    <div :class="tile">
      <p :class="label">Fichas publicadas</p>
      <p :class="value">{{ fmtNum(itemsTotal) }} <span v-if="past" :class="unit">{{ past }}</span></p>
      <p :class="sub">
        <template v-if="itemsTotal">
          <span :class="itemsNew ? 'font-medium text-adm-ok' : ''">+{{ fmtNum(itemsNew) }}</span> {{ per }} · {{ types }} {{ types === 1 ? 'tipo' : 'tipos' }}
        </template>
        <template v-else>Ninguna todavía</template>
      </p>
      <AdminStatsDelta :current="itemsNew" :previous="p ? sumCategories(p.itemsNew) : null" :noun="['nueva', 'nuevas']" />
    </div>
  </section>
</template>
