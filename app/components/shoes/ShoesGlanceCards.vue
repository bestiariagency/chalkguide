<script setup lang="ts">
import type { ShoeSummary } from '~/types/domain'

/** < md: one row-card per model (four columns do not fit in 390 px). */
defineProps<{ shoes: ShoeSummary[] }>()
const { t } = useI18n()
const { price, stiffnessWord, closure, profile } = useShoeGlanceLabels()
</script>

<template>
  <ul class="border-t border-line-strong tabular-nums" :aria-label="t('home.shoes.title')">
    <li v-for="shoe in shoes" :key="shoe.id" class="group/card relative border-b border-line-strong py-5">
      <div class="flex gap-4">
        <ShoesPhotoTile
          :media="shoe.cover"
          :brand="shoe.brand"
          :model="shoe.model"
          sizes="104px"
          class="h-[130px] w-[104px] shrink-0 shadow-(--shadow-slab-dark)"
        />
        <div class="min-w-0 flex-1">
          <p class="truncate text-note text-meta">{{ shoe.brand }}</p>
          <h3 class="text-xl leading-tight font-medium [overflow-wrap:anywhere]">
            <NuxtLinkLocale
              :to="{ name: 'climbing-shoes-slug', params: { slug: shoe.slug } }"
              class="after:absolute after:inset-0 after:z-[1] focus-visible:shadow-none focus-visible:after:ring-focus"
            >
              <span :class="cardTitleUnderline">{{ shoe.model }}</span>
            </NuxtLinkLocale>
          </h3>
          <p class="mt-1 font-mono text-accent">{{ price(shoe) }}</p>
          <ShoesGlanceBadges :shoe="shoe" class="relative z-[2] mt-2" />
        </div>
      </div>
      <dl class="mt-4 grid grid-cols-3 gap-3 text-caption">
        <div>
          <dt class="text-meta">{{ t('shoes.rows.closure') }}</dt>
          <dd>{{ closure(shoe) }}</dd>
        </div>
        <div>
          <dt class="text-meta">{{ t('shoes.rows.profile') }}</dt>
          <dd>{{ profile(shoe) }}</dd>
        </div>
        <div>
          <dt class="text-meta">{{ t('shoes.rows.stiffness') }}</dt>
          <template v-if="shoe.stiffness !== null">
            <dd>{{ stiffnessWord(shoe) }}</dd>
            <dd class="mt-1">
              <UiIndexBar
                :value="shoe.stiffness"
                :label="t('ratings.outOfValue', { value: shoe.stiffness })"
                class="w-full"
              />
            </dd>
          </template>
          <dd v-else class="text-meta">{{ t('common.noData') }}</dd>
        </div>
      </dl>
    </li>
  </ul>
</template>
