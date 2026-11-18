<script setup lang="ts">
import type { NuxtError } from '#app'
import { ArrowRight } from 'lucide-vue-next'
import { cardSurface } from '~/utils/card-classes'

const props = defineProps<{ error: NuxtError }>()
const { t } = useI18n()
const { isNotFound, code, title, body, spanishPath, retry } = useErrorPage(() => props.error)

const suggestions = [
  { to: { name: 'climbing-gyms' }, title: 'nav.gyms', body: 'nav.gymsDescriptionGeneric' },
  { to: { name: 'climbing-shoe-resoling' }, title: 'nav.resoling', body: 'nav.resolingDescription' },
  { to: { name: 'climbing-shoes' }, title: 'nav.shoes', body: 'nav.shoesDescription' },
] as const
</script>

<template>
  <NuxtLayout>
    <section class="board-tex border-b-[0.5px] border-line">
      <div class="mx-auto grid max-w-page items-center gap-10 px-4 py-16 md:px-6 md:py-24 lg:grid-cols-12">
        <div :class="isNotFound ? 'lg:col-span-7' : 'lg:col-span-12'">
          <p class="font-mono text-[64px] leading-none text-accent md:text-[96px]">{{ code }}</p>
          <h1 class="display mt-4 text-[2.125rem] leading-[1.08] md:text-[3rem]">{{ title }}</h1>
          <p class="mt-4 max-w-read text-[18px] leading-[1.7] text-meta">{{ body }}</p>
          <div class="mt-8 flex flex-wrap items-center gap-x-6 gap-y-3">
            <UiButton v-if="!isNotFound" @click="retry">{{ t('common.retry') }}</UiButton>
            <UiButton v-else :to="{ name: 'index' }">{{ t('states.notFoundHome') }}</UiButton>
            <UiTextLink v-if="!isNotFound" :to="{ name: 'index' }">{{ t('states.notFoundHome') }}</UiTextLink>
            <UiTextLink v-if="isNotFound" :to="{ name: 'blog' }">{{ t('nav.blog') }}</UiTextLink>
            <UiTextLink v-if="spanishPath" :href="spanishPath" hreflang="es">
              {{ t('states.notFoundSpanish') }}
            </UiTextLink>
          </div>
        </div>
        <div v-if="isNotFound" class="lg:col-span-5">
          <UiHandNote>{{ t('states.notFoundHand') }}</UiHandNote>
          <ul class="mt-4 space-y-3">
            <li v-for="item in suggestions" :key="item.title">
              <NuxtLinkLocale :to="item.to" :class="[cardSurface, 'flex items-center justify-between gap-3 p-5']">
                <span>
                  <span class="block font-medium">{{ t(item.title) }}</span>
                  <span class="block text-sm text-meta">{{ t(item.body) }}</span>
                </span>
                <ArrowRight class="size-5 text-meta" aria-hidden="true" />
              </NuxtLinkLocale>
            </li>
          </ul>
        </div>
      </div>
    </section>
  </NuxtLayout>
</template>
