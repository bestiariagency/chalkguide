<script setup lang="ts">
import { Plus } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'

/**
 * "Lado a lado" (README §9.9.1): capacity indicator, model adder, replace dialog and the
 * comparison itself (table from lg, attribute view below). State lives in the URL (parent).
 */
const props = defineProps<{
  shoes: ShoeSummary[]
  selected: ShoeSummary[]
  pending: ShoeSummary | null
  flashSlug: string | null
  checkedText: string | null
}>()
const dialogOpen = defineModel<boolean>('dialogOpen', { required: true })
const emit = defineEmits<{
  pick: [shoe: ShoeSummary]
  remove: [shoe: ShoeSummary]
  replace: [shoe: ShoeSummary]
}>()
const { t } = useI18n()

const adder = ref<{ focus: () => void } | null>(null)
const hintId = useId()
const left = computed(() => MAX_COMPARE - props.selected.length)
const hint = computed(() => {
  if (!props.selected.length) return t('shoes.compare.hintEmpty', { max: MAX_COMPARE })
  if (!left.value) return t('shoes.compare.hintFull', { max: MAX_COMPARE })
  return t('shoes.compare.hintLeft', left.value)
})
</script>

<template>
  <section id="comparacion" class="scroll-mt-16 border-t-[0.5px] border-line" aria-labelledby="shoes-compare">
    <div class="mx-auto max-w-page px-4 py-12 md:px-6 md:py-16">
      <div class="flex flex-wrap items-baseline justify-between gap-x-6 gap-y-2">
        <h2 id="shoes-compare" class="text-title-2 font-medium">{{ t('shoes.compare.title') }}</h2>
        <p class="flex items-center gap-2 text-caption text-meta">
          <span class="flex gap-1" aria-hidden="true">
            <span
              v-for="slot in MAX_COMPARE"
              :key="slot"
              class="size-2 rounded-full border border-control"
              :class="slot <= selected.length && '!border-accent-fill bg-accent-fill'"
            />
          </span>
          {{ t('shoes.compare.capacity', { count: selected.length, max: MAX_COMPARE }) }}
        </p>
      </div>

      <div class="mt-6 max-w-xl">
        <ShoesAdder
          ref="adder"
          :shoes="shoes"
          :selected-slugs="selected.map((s) => s.slug)"
          :hint-id="hintId"
          @pick="emit('pick', $event)"
        />
        <p :id="hintId" class="mt-2 text-note text-meta">{{ hint }}</p>
      </div>

      <div class="mt-8">
        <template v-if="selected.length >= 2">
          <ShoesCompareTable
            :shoes="selected"
            :flash-slug="flashSlug"
            @remove="emit('remove', $event)"
            @add="adder?.focus()"
          />
          <ShoesCompareByAttribute :shoes="selected" :flash-slug="flashSlug" @remove="emit('remove', $event)" />
        </template>
        <UiEmptyState
          v-else
          :title="selected[0] ? t('shoes.compare.oneTitle', { name: selected[0].model }) : t('common.compareMin')"
          :body="t('shoes.compare.minHint')"
        >
          <template #action>
            <div class="flex flex-wrap items-center justify-center gap-3">
              <UiButton v-if="selected[0]" variant="inline" class="min-h-11" @click="emit('remove', selected[0])">
                {{ selected[0].model }} <span aria-hidden="true">×</span>
                <span class="sr-only">{{ t('shoes.compare.removeNamed', { name: selected[0].model }) }}</span>
              </UiButton>
              <UiButton variant="ghost" :icon="Plus" @click="adder?.focus()">
                {{ t('shoes.compare.addModel') }}
              </UiButton>
            </div>
          </template>
        </UiEmptyState>
      </div>

      <p v-if="checkedText && selected.length >= 2" class="mt-3 font-mono text-note text-meta">
        {{ t('shoes.compare.pricesChecked', { date: checkedText }) }}
      </p>
      <div class="mt-5 flex max-w-read gap-3 text-caption text-meta">
        <UiBadge kind="affiliate" class="shrink-0 self-start">{{ t('transparency.affiliate') }}</UiBadge>
        <p>{{ t('transparency.affiliateHint') }} {{ t('shoes.compare.noLinkNote') }}</p>
      </div>
    </div>

    <ShoesReplaceDialog
      v-model:open="dialogOpen"
      :incoming="pending"
      :current="selected"
      @replace="emit('replace', $event)"
    />
  </section>
</template>
