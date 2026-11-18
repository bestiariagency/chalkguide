<script setup lang="ts">
import { Check, ExternalLink, Plus, X } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'

/**
 * Right-hand detail drawer of a model (full width on mobile): photo, key data, comparison toggle,
 * shop link (affiliate marked) and the link to the full page. role="dialog" aria-modal; Tab is
 * trapped, Esc and the scrim close, focus returns to the opener, body scroll is locked.
 */
const props = defineProps<{ shoe: ShoeSummary | null; selected: boolean }>()
const open = defineModel<boolean>('open', { required: true })
const emit = defineEmits<{ toggle: [shoe: ShoeSummary] }>()
const { t } = useI18n()
const { price: priceLabel } = useShoeGlanceLabels()

// Keep the last model while the panel slides out.
const current = ref<ShoeSummary | null>(props.shoe)
watch(
  () => props.shoe,
  (shoe) => shoe && (current.value = shoe),
)
const panel = ref<HTMLElement | null>(null)
const titleId = useId()
const noteId = useId()
useSheetBehaviour(open, panel)
const close = () => (open.value = false)

const price = computed(() => current.value && priceLabel(current.value))
const rows = computed(() => {
  const shoe = current.value
  if (!shoe) return []
  const noData = t('common.noData')
  const stiff = stiffnessGroup(shoe.stiffness)
  return [
    { key: 'level', value: shoe.levels.map((l) => t(`shoes.level.${l}`)).join(', ') || noData },
    { key: 'profile', value: shoe.profile ? t(`shoes.profile.${shoe.profile}`) : noData },
    { key: 'closure', value: shoe.closure ? t(`shoes.closure.${shoe.closure}`) : noData },
    { key: 'stiffness', value: stiff ? t(`shoes.stiffnessGroup.${stiff}`) : noData },
    { key: 'rubber', value: shoe.rubber ?? noData },
    { key: 'use', value: shoe.recommendedUse.map((u) => t(`shoes.use.${u}`)).join(', ') || noData },
  ]
})
const storeUrl = computed(() => (isHttpUrl(current.value?.affiliateUrl ?? null) ? current.value?.affiliateUrl : null))
</script>

<template>
  <div
    class="group fixed inset-0 z-50 transition-[visibility] duration-0"
    :class="open ? 'visible delay-0' : 'invisible delay-300'"
    :data-open="open"
    :aria-hidden="!open"
  >
    <div
      class="absolute inset-0 bg-(--scrim) opacity-0 transition-opacity duration-300 ease-standard group-data-[open=true]:opacity-100 motion-reduce:transition-none"
      @click="close"
    />
    <div
      ref="panel"
      role="dialog"
      aria-modal="true"
      :aria-labelledby="titleId"
      class="absolute inset-y-0 right-0 w-full translate-x-full overflow-y-auto bg-board transition-transform duration-[250ms] ease-in group-data-[open=true]:translate-x-0 group-data-[open=true]:duration-300 group-data-[open=true]:ease-out sm:max-w-md motion-reduce:transition-none"
    >
      <template v-if="current">
        <div class="relative">
          <ShoesPhotoTile :media="current.cover" :brand="current.brand" :model="current.model" sizes="100vw sm:448px" eager class="aspect-[4/3] w-full !rounded-none" />
          <button
            type="button"
            class="absolute top-4 right-4 grid size-11 place-items-center rounded-full bg-board text-foreground shadow-sm hover:bg-elevated focus-visible:ring-focus"
            :aria-label="t('common.close')"
            @click="close"
          >
            <X :size="18" aria-hidden="true" />
          </button>
        </div>
        <div class="p-6 pb-[calc(24px+env(safe-area-inset-bottom))]">
          <p class="label-mini">{{ current.brand }}</p>
          <h2 :id="titleId" class="mt-2 text-title-3 leading-tight font-medium">{{ current.model }}</h2>
          <p class="mt-2 font-mono text-data text-accent tabular-nums">{{ price }}</p>

          <dl class="mt-5 grid grid-cols-2 rounded-lg border-[0.5px] border-line-strong text-body-sm">
            <div
              v-for="(row, index) in rows"
              :key="row.key"
              class="min-w-0 p-3"
              :class="[
                index % 2 === 0 && 'border-r-[0.5px] border-line-strong',
                index < 4 && 'border-b-[0.5px] border-line-strong',
              ]"
            >
              <dt class="label-mini">{{ t(`shoes.rows.${row.key}`) }}</dt>
              <dd class="mt-1.5 [overflow-wrap:anywhere]">{{ row.value }}</dd>
            </div>
          </dl>

          <div class="mt-5 grid gap-3">
            <button
              type="button"
              :aria-pressed="selected"
              class="inline-flex min-h-11 items-center justify-center gap-2 rounded-md px-4 text-body-sm font-medium transition-colors duration-200 focus-visible:ring-focus"
              :class="
                selected
                  ? 'bg-foreground text-background'
                  : 'border border-control text-foreground hover:border-meta hover:bg-elevated'
              "
              @click="emit('toggle', current)"
            >
              <component :is="selected ? Check : Plus" :size="16" aria-hidden="true" />
              {{ selected ? t('shoes.drawer.inComparator') : t('shoes.drawer.addToComparator') }}
            </button>
            <UiButton
              v-if="storeUrl"
              :href="storeUrl"
              :icon="ExternalLink"
              target="_blank"
              :rel="current.isAffiliate ? 'sponsored nofollow noopener' : 'nofollow noopener'"
              :aria-describedby="current.isAffiliate ? noteId : undefined"
            >
              {{ t('shoes.drawer.seeInStore') }}
            </UiButton>
          </div>
          <p v-if="storeUrl && current.isAffiliate" :id="noteId" class="mt-4 text-note text-meta">
            {{ t('shoes.drawer.affiliateNote') }}
          </p>
          <p class="mt-4 text-center">
            <UiTextLink :to="{ name: 'climbing-shoes-slug', params: { slug: current.slug } }">
              {{ t('shoes.drawer.fullPage') }}
            </UiTextLink>
          </p>
        </div>
      </template>
    </div>
  </div>
</template>
