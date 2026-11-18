<script setup lang="ts">
import { Check, Eye, Plus } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'

/**
 * Model card. The title is a real link whose overlay covers the card (click anywhere goes to the
 * model page). Two round buttons sit above the overlay: the eye opens the detail drawer, the
 * plus/check toggles the comparison (with 3 chosen, the parent asks which one to replace).
 */
const props = withDefaults(
  defineProps<{ shoe: ShoeSummary; selected: boolean; tokens?: string[] }>(),
  { tokens: () => [] },
)
const emit = defineEmits<{ toggle: []; open: [] }>()
const { t } = useI18n()
const { price: priceLabel } = useShoeGlanceLabels()

const meta = computed(() =>
  [
    props.shoe.profile && t(`shoes.profile.${props.shoe.profile}`),
    props.shoe.closure && t(`shoes.closure.${props.shoe.closure}`),
  ]
    .filter(Boolean)
    .join(' · '),
)
const price = computed(() => priceLabel(props.shoe))

function onPreview(event: MouseEvent) {
  // Safari does not focus clicked buttons: focus it so the drawer returns focus here on close.
  ;(event.currentTarget as HTMLElement | null)?.focus()
  emit('open')
}
</script>

<template>
  <article
    class="group/card flex h-full flex-col overflow-hidden"
    :class="[cardSurface, selected && '!border-accent']"
    :data-shoe-card="shoe.slug"
  >
    <div class="relative">
      <ShoesPhotoTile
        :media="shoe.cover"
        :brand="shoe.brand"
        :model="shoe.model"
        sizes="100vw sm:50vw xl:33vw"
        class="aspect-[4/3] !rounded-none"
      />
      <span
        v-if="shoe.ownedByAuthor"
        class="absolute top-3 left-3 rounded-sm bg-foreground px-2 py-1.25 text-micro leading-[1.3] font-medium text-background"
      >
        {{ t('shoes.usedBadge') }}
      </span>
      <div class="absolute top-3 right-3 z-[2] flex items-center">
        <button
          type="button"
          class="grid size-11 place-items-center rounded-full focus-visible:ring-focus"
          aria-haspopup="dialog"
          :aria-label="t('shoes.list.previewNamed', { name: shoe.model })"
          @click="onPreview"
        >
          <span
            class="grid size-8 place-items-center rounded-full border-[0.5px] border-line-strong bg-board text-foreground transition-colors duration-200 group-hover/card:border-control"
          >
            <Eye :size="16" aria-hidden="true" />
          </span>
        </button>
        <button
          type="button"
          class="grid size-11 place-items-center rounded-full focus-visible:ring-focus"
          :aria-pressed="selected"
          :aria-label="
            selected
              ? t('shoes.compare.removeNamed', { name: shoe.model })
              : t('shoes.compare.addNamed', { name: shoe.model })
          "
          @click="emit('toggle')"
        >
          <span
            class="grid size-8 place-items-center rounded-full border-[0.5px] transition-colors duration-200"
            :class="
              selected
                ? 'border-accent-fill bg-accent-fill text-on-accent'
                : 'border-line-strong bg-board text-foreground group-hover/card:border-control'
            "
          >
            <component :is="selected ? Check : Plus" :size="16" aria-hidden="true" />
          </span>
        </button>
      </div>
    </div>
    <div class="flex flex-1 flex-col p-5">
      <p class="text-note font-medium text-meta"><UiHighlight :text="shoe.brand" :tokens="tokens" /></p>
      <h3 class="mt-2 text-lg leading-snug font-medium">
        <NuxtLinkLocale
          :to="{ name: 'climbing-shoes-slug', params: { slug: shoe.slug } }"
          class="rounded-sm after:absolute after:inset-0 after:z-[1] focus-visible:shadow-none"
        >
          <span :class="cardTitleUnderline"><UiHighlight :text="shoe.model" :tokens="tokens" /></span>
        </NuxtLinkLocale>
      </h3>
      <p class="mt-2 flex items-center gap-2 text-caption text-meta">
        <ShoesAggression :profile="shoe.profile" />
        <span>{{ meta }}</span>
      </p>
      <p v-if="shoe.rubber" class="mt-2 text-caption text-meta">
        <UiHighlight :text="shoe.rubber" :tokens="tokens" />
      </p>
      <div class="mt-auto pt-4">
        <div class="flex items-center justify-between gap-2 border-t-[0.5px] border-line pt-3">
          <p class="font-mono tabular-nums" :class="shoe.priceMin !== null ? 'text-accent' : 'text-meta'">
            {{ price }}
          </p>
          <UiBadge v-if="shoe.isAffiliate" kind="affiliate">{{ t('shoes.affiliateBadge') }}</UiBadge>
        </div>
      </div>
    </div>
  </article>
</template>
