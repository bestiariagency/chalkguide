<script setup lang="ts">
import type { ShoeSummary } from '~/types/domain'

/** md+: transposed table (columns = models), the plaque (photo or poster) as the column header. */
defineProps<{ shoes: ShoeSummary[] }>()
const { t } = useI18n()
const { price, stiffnessWord, closure, profile } = useShoeGlanceLabels()
const labelCell = 'py-3 pr-2 font-normal text-meta'
const cell = 'px-2 py-3 align-middle lg:px-3'
</script>

<template>
  <div class="tabular-nums">
    <table class="w-full table-fixed text-left text-body-sm">
      <caption class="sr-only">
        {{
          t('home.shoes.caption')
        }}
      </caption>
      <thead>
        <tr>
          <th scope="col" class="w-[88px] lg:w-[120px]">
            <span class="sr-only">{{ t('shoes.columns.model') }}</span>
          </th>
          <th v-for="shoe in shoes" :key="shoe.id" scope="col" class="px-2 pb-5 align-top font-normal lg:px-3">
            <NuxtLinkLocale
              :to="{ name: 'climbing-shoes-slug', params: { slug: shoe.slug } }"
              class="group/card block"
            >
              <span
                class="relative block aspect-[4/5] overflow-hidden slab-dark bg-tray-paper text-ink before:pointer-events-none before:absolute before:inset-0 before:bg-[linear-gradient(118deg,rgb(255_255_255/0)_30%,rgb(255_255_255/.28)_46%,rgb(255_255_255/0)_62%)]"
              >
                <ShoesPhotoTile
                  :media="shoe.cover"
                  :model="shoe.model"
                  top
                  class="absolute inset-x-0 top-0 h-[66%] !rounded-none !bg-transparent"
                />
                <span class="absolute inset-x-0 bottom-0 p-3 lg:p-4">
                  <span class="block text-note leading-tight font-medium text-meta-ink">{{ shoe.brand }}</span>
                  <span class="mt-1 block text-[17px] leading-[1.25] font-medium tracking-[-0.01em] [overflow-wrap:anywhere] lg:text-[19px]">
                    <span :class="plaqueTitleUnderline">{{ shoe.model }}</span>
                  </span>
                </span>
              </span>
            </NuxtLinkLocale>
            <ShoesGlanceBadges :shoe="shoe" class="mt-3" />
          </th>
        </tr>
      </thead>
      <tbody>
        <tr class="border-t border-line-strong">
          <th scope="row" :class="labelCell">{{ t('shoes.rows.closure') }}</th>
          <td v-for="shoe in shoes" :key="shoe.id" :class="cell">{{ closure(shoe) }}</td>
        </tr>
        <tr class="border-t border-line-strong">
          <th scope="row" :class="labelCell">{{ t('shoes.rows.profile') }}</th>
          <td v-for="shoe in shoes" :key="shoe.id" :class="cell">{{ profile(shoe) }}</td>
        </tr>
        <tr class="border-t border-line-strong">
          <th scope="row" :class="labelCell">{{ t('shoes.rows.stiffness') }}</th>
          <td v-for="shoe in shoes" :key="shoe.id" :class="cell">
            <span
              v-if="shoe.stiffness !== null"
              class="flex flex-col-reverse items-start gap-1.5 lg:flex-row lg:items-center lg:gap-2.5"
            >
              <UiIndexBar
                :value="shoe.stiffness"
                :label="t('ratings.outOfValue', { value: shoe.stiffness })"
                class="w-full max-w-20 shrink-0 lg:w-20"
              />
              <span>{{ stiffnessWord(shoe) }}</span>
            </span>
            <span v-else class="text-meta">{{ t('common.noData') }}</span>
          </td>
        </tr>
        <tr class="border-y border-line-strong">
          <th scope="row" :class="[labelCell, '!text-foreground']">{{ t('shoes.rows.price') }}</th>
          <td v-for="shoe in shoes" :key="shoe.id" :class="cell" class="font-mono whitespace-nowrap text-accent">
            {{ price(shoe) }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
