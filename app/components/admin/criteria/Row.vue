<script setup lang="ts">
import { Sigma, Table2 } from 'lucide-vue-next'
import { criterionEffect, noteCount, usageText, type AdminCriterion, type CriterionUsage } from '~/utils/admin-criteria'

/** Name, key and usage of a criterion (shared by the active and the inactive lists). The name opens the drawer. */
const props = defineProps<{ criterion: AdminCriterion; usage: CriterionUsage; position?: number; inactive?: boolean }>()
defineEmits<{ edit: [] }>()
const effect = computed(() => criterionEffect(props.criterion))
const usageLabel = computed(() => usageText(props.usage))
</script>

<template>
  <div class="flex min-w-0 items-center gap-2">
    <span v-if="position" class="hidden w-4 flex-none text-right text-xs text-adm-muted tabular-nums sm:inline" aria-hidden="true">{{ position }}</span>
    <button type="button" class="min-w-0 flex-1 rounded py-1 text-left" @click="$emit('edit')">
      <span :class="['block truncate text-sm font-medium', inactive && 'text-adm-meta']">{{ criterion.name_es }}</span>
      <span class="hidden truncate font-mono text-[11px] text-adm-muted md:block">{{ criterion.key }}</span>
      <span class="block truncate text-xs text-adm-meta tabular-nums md:hidden">{{ usageLabel }}{{ inactive ? ' · conservadas' : '' }}</span>
    </button>
    <span v-if="effect" :class="[admChip, 'bg-adm-subtle text-adm-meta']" :title="`${effect.title}: ${effect.detail}`">
      <Sigma v-if="effect.kind === 'index'" aria-hidden="true" /><Table2 v-else aria-hidden="true" />
      <span class="max-sm:sr-only">{{ effect.title }}</span>
    </span>
    <span :class="['hidden w-36 text-right text-xs tabular-nums md:inline', noteCount(props.usage) ? 'text-adm-meta' : 'text-adm-muted italic']">{{ usageLabel }}{{ inactive && noteCount(props.usage) ? ' · conservadas' : '' }}</span>
  </div>
</template>
