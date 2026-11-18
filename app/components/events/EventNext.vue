<script setup lang="ts">
import { ArrowUpRight } from 'lucide-vue-next'
import type { GuideEvent } from '~/types/domain'

/**
 * "El siguiente" (§13.7): first non-cancelled activity of the month on a slab. Big date over the
 * gym's cover (or the typographic poster) circled in chalk; to the right "el siguiente" in
 * Caveat, title, place, time and price, and "Más información". Mobile: photo (4:3) then details.
 */
const props = defineProps<{ event: GuideEvent }>()
const { t, locale } = useI18n()
const info = computed(() => eventDay(props.event, locale.value))
const photo = computed(() => (props.event.cover ? { ...props.event.cover, alt: '' } : null))
const when = computed(() => formatDate(props.event.startsAt, locale.value, { weekday: 'long', day: 'numeric', month: 'long' }))
const time = computed(() => (props.event.allDay ? t('events.allDay') : formatTime(props.event.startsAt, locale.value)))
const foreignGym = computed(() => locale.value === 'en' && !props.event.gymHasEn)
</script>

<template>
  <div class="slab grid overflow-hidden bg-board lg:grid-cols-12">
    <div
      class="relative isolate flex aspect-[4/3] sm:aspect-[16/9] flex-col items-start justify-end overflow-hidden p-5 lg:col-span-7 lg:aspect-auto lg:min-h-[340px] lg:p-8"
      :class="photo ? 'bg-ink text-white' : 'bg-tray-paper text-ink'"
      aria-hidden="true"
    >
      <template v-if="photo">
        <div class="absolute inset-0 -z-20"><UiPhoto :media="photo" sizes="xs:100vw sm:100vw md:100vw lg:700px" class="size-full" /></div>
        <div class="absolute inset-0 -z-10 bg-black/56" />
      </template>
      <span class="text-body-sm font-medium tracking-[.02em]">{{ info.weekday }}</span>
      <UiChalkStroke variant="circle">
        <span class="display-date block px-4 py-1 text-[64px] leading-none lg:px-6 lg:text-[120px]">{{ info.day }} {{ info.month }}</span>
      </UiChalkStroke>
    </div>
    <div class="flex min-w-0 flex-col justify-center gap-3 p-5 lg:col-span-5 lg:p-8">
      <p class="-rotate-1 font-hand text-hand text-accent">{{ t('events.next') }}</p>
      <p class="sr-only"><time :datetime="event.startsAt">{{ when }}</time></p>
      <h3 class="text-title-3 font-medium lg:text-[32px] lg:leading-[1.15]">{{ event.title }}</h3>
      <p v-if="event.place" class="text-body-sm text-meta">
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
      </p>
      <dl class="flex flex-wrap gap-x-6 gap-y-1 font-mono text-body-sm text-meta">
        <div>
          <dt class="sr-only">{{ t('events.time') }}</dt>
          <dd>{{ time }}</dd>
        </div>
        <div v-if="event.priceText">
          <dt class="sr-only">{{ t('events.price') }}</dt>
          <dd>{{ event.priceText }}</dd>
        </div>
      </dl>
      <p v-if="event.url" class="mt-2">
        <UiButton :href="event.url" variant="ghost" target="_blank" rel="noopener" class="min-h-[52px]">
          {{ t('events.moreInfo') }}
          <ArrowUpRight :size="18" class="ml-2" aria-hidden="true" />
          <span class="sr-only"> · {{ event.title }}</span>
        </UiButton>
      </p>
    </div>
  </div>
</template>
