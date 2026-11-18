<script setup lang="ts">
import type { GuideEvent } from '~/types/domain'

/**
 * Date tile of an agenda row (D49, §13.7): the gym's cover under a 56 % veil with white date, or,
 * without a photo, a typographic poster on `tray`. Cancelled: grey photo. Decorative (the row
 * carries the date as text for assistive tech).
 */
const props = defineProps<{ event: GuideEvent; archive?: boolean }>()
const { locale } = useI18n()
const info = computed(() => eventDay(props.event, locale.value))
const photo = computed(() => (props.event.cover ? { ...props.event.cover, alt: '' } : null))
const grey = computed(() => props.event.cancelled || props.archive)
</script>

<template>
  <div
    class="relative isolate flex size-24 shrink-0 flex-col justify-end overflow-hidden rounded-slab p-2.5 min-[900px]:h-[120px] min-[900px]:w-[168px] min-[900px]:p-3.5"
    :class="photo ? 'bg-ink text-white' : 'bg-tray-paper text-ink ring-1 ring-line ring-inset'"
    aria-hidden="true"
  >
    <div v-if="photo" class="absolute inset-0 -z-20" :class="grey && 'grayscale'">
      <UiPhoto :media="photo" sizes="xs:96px sm:96px md:168px" class="size-full" />
    </div>
    <div v-if="photo" class="absolute inset-0 -z-10" :class="grey ? 'bg-black/66' : 'bg-black/56'" />
    <span class="text-note leading-none font-medium tracking-[.02em] whitespace-nowrap">{{ info.weekday }}</span>
    <span
      class="display-date mt-1 leading-none whitespace-nowrap"
      :class="info.multi ? 'text-[28px] min-[900px]:text-[44px]' : 'text-[40px] min-[900px]:text-[56px]'"
    >
      {{ info.day }}
    </span>
  </div>
</template>
