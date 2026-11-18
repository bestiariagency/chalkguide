<script setup lang="ts">
import { ArrowLeftRight } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'

/** "¿Cuál sustituyes?": bottom sheet on mobile, modal from md. Focus lands on the first option. */
defineProps<{ incoming: ShoeSummary | null; current: ShoeSummary[] }>()
const open = defineModel<boolean>('open', { required: true })
const emit = defineEmits<{ replace: [shoe: ShoeSummary] }>()
const { t, locale } = useI18n()
</script>

<template>
  <UiSheet
    v-model:open="open"
    :title="t('shoes.compare.replace.title')"
    :close-label="t('common.close')"
  >
    <template v-if="incoming">
      <p class="text-body-sm text-meta">
        {{ t('shoes.compare.replace.body', { max: MAX_COMPARE, name: incoming.model }) }}
      </p>
      <ul class="mt-4 space-y-2">
        <li v-for="(shoe, index) in current" :key="shoe.id">
          <button
            type="button"
            class="flex min-h-14 w-full items-center gap-3 rounded-md border border-control px-4 py-2 text-left hover:border-meta hover:bg-elevated"
            :data-autofocus="index === 0 || undefined"
            @click="emit('replace', shoe)"
          >
            <ArrowLeftRight :size="18" aria-hidden="true" class="shrink-0 text-meta" />
            <span class="min-w-0">
              <span class="block font-medium">{{ t('shoes.compare.replace.option', { name: shoe.model }) }}</span>
              <span class="block truncate text-caption text-meta">
                {{ shoe.brand }}<template v-if="shoe.priceMin !== null || shoe.priceMax !== null">
                  · <span class="font-mono">{{ formatEurRange(shoe.priceMin, shoe.priceMax, locale) }}</span></template>
              </span>
            </span>
          </button>
        </li>
      </ul>
      <UiButton variant="ghost" class="mt-4 w-full" @click="open = false">
        {{ t('common.cancel') }}
      </UiButton>
    </template>
  </UiSheet>
</template>
