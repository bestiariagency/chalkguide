<script setup lang="ts">
import type { ResolerForm } from '~/utils/resoler-fields'

/** Tabs that only resolers have (location without schedule, services and prices) plus the review without indices. */
defineProps<{ tab: string }>()
const { editor } = useItemEditorContext<ResolerForm>()
const { form, errors } = editor
</script>

<template>
  <template v-if="form">
    <AdminItemsAddress v-if="tab === 'location'" v-model:form="form" :errors="errors" :changed="editor.changed.value" />
    <AdminResolersPanelServices v-else-if="tab === 'services'" v-model:form="form" :errors="errors" :changed="editor.changed.value" :live="editor.live.value" :busy="editor.busy.value" @verify="editor.verifyToday($event, 'prices_verified_at')" />
    <AdminItemsPanelReview v-else-if="tab === 'review'" v-model:form="form" :errors="errors" :changed="editor.changed.value" :criteria="editor.loaded.value?.criteria ?? []" :info="RESOLER_INFO" @media="editor.remember" />
  </template>
</template>
