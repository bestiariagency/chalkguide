<script setup lang="ts">
import { CircleCheck, CircleMinus } from 'lucide-vue-next'

/**
 * «Tu elección» block of /cookies (D86, README §16.4): the saved choice per category, with a button
 * that opens the preferences panel. Without JS (and until hydration) it only explains that nothing
 * is loaded, so the server HTML is the same for everyone and never claims a choice.
 */
const { t, locale } = useI18n()
const { state, open } = useConsent()
const titleId = useId()
const ready = ref(false)
onMounted(() => (ready.value = true))

const rows = computed(() =>
  (['analytics', 'ads'] as const).map((key) => ({
    key,
    title: t(`cookies.category.${key}.title`),
    on: state.value[key],
  })),
)
const savedOn = computed(() =>
  state.value.date ? t('cookies.choice.savedOn', { date: formatDate(state.value.date, String(locale.value)) }) : null,
)
</script>

<template>
  <section :id="t('cookies.choice.anchor')" :aria-labelledby="titleId" class="slab mb-10 scroll-mt-24 bg-board">
    <div class="grid gap-4 p-5 md:grid-cols-[minmax(0,1fr)_auto] md:items-start md:gap-6 md:p-7">
      <div class="min-w-0">
        <h2 :id="titleId" class="text-[20px] leading-tight font-medium tracking-[-0.01em] md:text-[22px]">
          {{ t('cookies.choice.title') }}
        </h2>
        <p v-if="!ready" class="mt-2 max-w-[56ch] text-body-sm text-meta">{{ t('cookies.choice.noJs') }}</p>
        <template v-else-if="state.chosen">
          <p v-if="savedOn" class="mt-2 text-body-sm text-meta">{{ savedOn }}</p>
          <ul class="mt-4 grid gap-2" aria-live="polite">
            <li v-for="row in rows" :key="row.key" class="flex flex-wrap items-center gap-x-3 gap-y-1">
              <span class="text-body-sm font-medium">{{ row.title }}</span>
              <span
                class="inline-flex items-center gap-1.5 rounded-xs px-2 py-1 text-note font-medium whitespace-nowrap"
                :class="row.on ? 'bg-success-muted text-success-text' : 'bg-elevated text-meta'"
              >
                <component :is="row.on ? CircleCheck : CircleMinus" :size="14" aria-hidden="true" />
                {{ row.on ? t('cookies.choice.on') : t('cookies.choice.off') }}
              </span>
            </li>
          </ul>
        </template>
        <p v-else class="mt-2 max-w-[56ch] text-body-sm text-meta">{{ t('cookies.choice.none') }}</p>
      </div>
      <div v-if="ready" class="md:pt-1">
        <UiButton variant="ghost" aria-haspopup="dialog" @click="open">
          {{ state.chosen ? t('cookies.choice.change') : t('cookies.choice.chooseNow') }}
        </UiButton>
      </div>
    </div>
  </section>
</template>
