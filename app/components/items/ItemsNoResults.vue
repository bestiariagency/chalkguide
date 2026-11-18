<script setup lang="ts">
import { SearchX, SlidersHorizontal } from 'lucide-vue-next'

/**
 * Empty result of a guide listing. Says what is wrong (the search, the filters or both) and
 * offers the way out: clear filters, clear the search, or tell the author something is missing.
 */
const props = defineProps<{
  /** Trimmed search text ('' without search). */
  query: string
  activeFilters: number
  /** Singular noun of the listing ("rocódromo"). */
  noun: string
}>()
const emit = defineEmits<{ clearFilters: []; clearQuery: [] }>()
const { t } = useI18n()
const { data: settings } = useSiteSettings()
const email = computed(() => settings.value?.contactEmail)

const title = computed(() =>
  props.query
    ? t('common.search.noMatch', { noun: props.noun, query: props.query })
    : t('states.noResultsTitle'),
)
const body = computed(() =>
  props.query
    ? props.activeFilters
      ? t('common.search.alsoFilters', props.activeFilters)
      : t('common.search.tryOther')
    : t('states.noResultsBody'),
)
</script>

<template>
  <UiEmptyState
    :icon="query ? SearchX : SlidersHorizontal"
    :title="title"
    :body="body"
    class="mt-6"
    role="status"
  >
    <template #action>
      <div class="flex flex-wrap justify-center gap-3">
        <UiButton v-if="activeFilters" variant="ghost" @click="emit('clearFilters')">
          {{ t('common.clearFilters') }}
        </UiButton>
        <UiButton v-if="query" variant="ghost" @click="emit('clearQuery')">
          {{ t('common.search.clear') }}
        </UiButton>
      </div>
      <p v-if="email" class="mt-4 text-caption text-meta">
        {{ t('common.search.missing', { noun }) }}
        <UiTextLink :href="`mailto:${email}`">{{ t('common.search.tellMe') }}</UiTextLink>
      </p>
    </template>
  </UiEmptyState>
</template>
