<script setup lang="ts">
import type { GymForm } from '~/utils/gym-fields'

/** Tabs that only gyms have (location and hours, prices, facilities, grades and style) plus the review with its indices. */
defineProps<{ tab: string }>()
const { id, editor } = useItemEditorContext<GymForm>()
const { form, errors } = editor
const indices = useGymIndices(id, form, errors, () => editor.loaded.value?.indices ?? null)
const criteria = computed(() => editor.loaded.value?.criteria ?? [])
</script>

<template>
  <template v-if="form">
    <AdminGymsPanelLocation v-if="tab === 'location'" v-model:form="form" :errors="errors" :changed="editor.changed.value" />
    <AdminGymsPanelPrices v-else-if="tab === 'prices'" v-model:form="form" :errors="errors" :changed="editor.changed.value" :published="editor.live.value ? editor.published.value : null" />
    <AdminGymsPanelFacilities v-else-if="tab === 'facilities'" v-model:form="form" :errors="errors" :changed="editor.changed.value" />
    <AdminGymsPanelStyle v-else-if="tab === 'style'" v-model:form="form" :changed="editor.changed.value" />
    <AdminItemsPanelReview
      v-else-if="tab === 'review'"
      v-model:form="form"
      :errors="errors"
      :changed="editor.changed.value"
      :criteria="criteria"
      :info="GYM_INFO"
      :indices="indices"
      :family-complete="familyComplete(form, criteria)"
      @media="editor.remember"
    />
  </template>
</template>
