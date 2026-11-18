<script setup lang="ts">
import type { AuthorScore } from '~/types/domain'
import type { AuthorReview } from '~/types/item-detail'

/**
 * The author's review: first and prominent (project rule). A guest visit is announced in a
 * transparency aside before the text. The body is `SafeHtml` (sanitized by the server).
 */
const props = defineProps<{
  review: AuthorReview | null
  criteria: AuthorScore[]
  overall: number | null
  /** Section heading ("Mi reseña" / "Mi experiencia"). */
  title: string
  /** Shown when the author has not written the review yet. */
  emptyText: string
  /** Label before the date, e.g. "visitado el" (default) or "resolado en" with `monthOnly`. */
  dateLabel?: string
  /** Show "julio de 2026" instead of a short numeric date. */
  monthOnly?: boolean
  /** Text after the date for paid / guest visits ("pagado por mí", "invitado"). */
  paidLabel?: string
  guestLabel?: string
  /** Without a review, show only `emptyText` (no heading over a one-line note). */
  hideEmptyTitle?: boolean
  /** Shoes: show the headline as a "Lo que aprendí" note after the text instead of as a quote. */
  learnedTitle?: string
}>()
const { t, locale } = useI18n()
const { linkFor } = usePageLinks()

const visitDate = computed(() => {
  const iso = props.review?.visitDate
  if (!iso) return null
  return props.monthOnly
    ? formatDate(iso, locale.value, { month: 'long', year: 'numeric' })
    : formatDate(iso, locale.value, { day: '2-digit', month: '2-digit', year: '2-digit' })
})
const visitKind = computed(() =>
  props.review?.visitType === 'invited' ? props.guestLabel : props.paidLabel,
)
</script>

<template>
  <section id="review" class="scroll-mt-20" :aria-label="title">
    <h2 v-if="review || !hideEmptyTitle" class="label-mini !text-accent">
      {{ title }}
    </h2>

    <template v-if="review">
      <div class="mt-5 flex items-center gap-3">
        <div
          class="grid size-10 place-items-center rounded-full border-[0.5px] border-line-strong bg-elevated text-caption font-medium text-accent"
          aria-hidden="true"
        >
          {{ t('gyms.detail.authorInitial') }}
        </div>
        <p class="text-caption text-meta">
          <span class="text-foreground">{{ t('gyms.detail.authorName') }}</span>
          <template v-if="visitDate">
            · {{ dateLabel ?? t('gyms.detail.visitedOn') }}
            <span :class="monthOnly ? '' : 'font-mono'">{{ visitDate }}</span>
          </template>
          <template v-if="visitKind"> · {{ visitKind }}</template>
        </p>
      </div>

      <!-- Facts that belong to the author line (e.g. the shoe size strip). -->
      <slot name="after-author" />

      <UiHandNote v-if="review.headline && !learnedTitle" class="mt-5" as="p">
        «{{ review.headline }}»
      </UiHandNote>

      <aside
        v-if="review.visitType === 'invited'"
        class="mt-6 flex max-w-read gap-3 rounded-lg border-[0.5px] border-accent/60 bg-accent-muted/40 p-4"
        :aria-label="t('gyms.detail.transparencyNotice')"
      >
        <UiBadge kind="guest-visit" class="self-start shrink-0 whitespace-nowrap">{{ t('transparency.guestVisit') }}</UiBadge>
        <div class="text-body-sm">
          <p>{{ review.disclosureNote ?? t('transparency.guestVisitHint') }}</p>
          <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')" variant="accent" class="mt-1 text-caption">
            {{ t('transparency.learnMore') }}
          </UiTextLink>
        </div>
      </aside>

      <UiProse v-if="review.bodyHtml" :html="review.bodyHtml" :heading-offset="1" class="mt-8" />
      <UiHandNote
        v-if="review.headline && learnedTitle"
        variant="learned"
        :title="learnedTitle"
        class="mt-8 max-w-read"
      >
        {{ review.headline }}
      </UiHandNote>
    </template>
    <p v-else class="text-meta" :class="!hideEmptyTitle && 'mt-5'">{{ emptyText }}</p>

    <ItemsCriteria
      v-if="criteria.length"
      :title="t('ratings.author')"
      :overall="overall"
      :criteria="criteria"
      class="mt-10"
    />
  </section>
</template>
