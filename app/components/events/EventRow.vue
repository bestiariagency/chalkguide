<script setup lang="ts">
import { Ban } from 'lucide-vue-next'
import type { GuideEvent } from '~/types/domain'

/**
 * Agenda row, poster style (D49, §13.7): date tile | title and "Tipo en Lugar" | time · price in
 * mono | "Más información". Information in the order people look for it. No price or no link: the
 * cell stays empty. Mobile: tile left of the title, a strip below with time · price and the link.
 */
const props = defineProps<{ event: GuideEvent; archive?: boolean }>()
const { t, locale } = useI18n()

const when = computed(() => formatDate(props.event.startsAt, locale.value, { weekday: 'long', day: 'numeric', month: 'long' }))
const time = computed(() => (props.event.allDay ? t('events.allDay') : formatTime(props.event.startsAt, locale.value)))
const foreignGym = computed(() => locale.value === 'en' && !props.event.gymHasEn)
</script>

<template>
  <li class="grid grid-cols-[96px_minmax(0,1fr)] items-center gap-x-4 gap-y-3 border-b-[0.5px] border-line py-5 min-[900px]:grid-cols-[168px_minmax(0,1fr)_minmax(150px,auto)_auto] min-[900px]:gap-x-6 min-[900px]:py-6">
    <EventsEventDateTile :event="event" :archive="archive" />
    <div class="min-w-0">
      <p class="sr-only">
        <time :datetime="event.startsAt">{{ when }}</time>
      </p>
      <p v-if="event.cancelled" class="mb-1">
        <UiBadge kind="stale" :icon="Ban">{{ t('events.cancelled') }}</UiBadge>
      </p>
      <h3 class="text-[19px] leading-snug font-medium min-[900px]:text-2xl" :class="event.cancelled && 'text-meta line-through'">
        {{ event.title }}
      </h3>
      <p class="text-body-sm text-meta">
        {{ t(`events.types.${event.type}`) }}
        <template v-if="event.place">
          {{ ' ' }}{{ t('events.at') }}{{ ' ' }}
          <UiTextLink
            v-if="event.gymSlug"
            :to="{ name: 'climbing-gyms-slug', params: { slug: event.gymSlug } }"
            :locale="foreignGym ? 'es' : undefined"
            :hreflang="foreignGym ? 'es' : undefined"
            class="relative after:absolute after:-inset-y-3 after:inset-x-0 after:content-['']"
          >
            {{ event.place }}
          </UiTextLink>
          <template v-else>{{ event.place }}</template>
        </template>
      </p>
    </div>
    <div class="col-span-2 flex items-center justify-between gap-3 border-t-[0.5px] border-line pt-3 min-[900px]:contents">
      <p class="font-mono text-note text-meta min-[900px]:text-body-sm">
        <span class="whitespace-nowrap">{{ time }}</span>
        <template v-if="event.priceText">
          <span class="min-[900px]:hidden" aria-hidden="true">{{ ' · ' }}</span>
          <span class="whitespace-nowrap min-[900px]:block">{{ event.priceText }}</span>
        </template>
      </p>
      <p>
        <UiTextLink v-if="event.url" :href="event.url" external class="text-body-sm relative after:absolute after:-inset-y-3 after:inset-x-0 after:content-['']">
          {{ t('events.moreInfo') }}
          <span class="sr-only"> · {{ event.title }}</span>
        </UiTextLink>
      </p>
    </div>
  </li>
</template>
