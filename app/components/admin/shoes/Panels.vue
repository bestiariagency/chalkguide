<script setup lang="ts">
import type { ShoeForm } from '~/utils/shoe-fields'

/** Tabs that only shoes have: technical sheet, price and affiliate, and "Lo que aprendí". */
defineProps<{ tab: string }>()
const { editor } = useItemEditorContext<ShoeForm>()
const { form, errors } = editor
</script>

<template>
  <template v-if="form">
    <AdminShoesPanelSpecs v-if="tab === 'specs'" v-model:form="form" :errors="errors" :changed="editor.changed.value" />
    <AdminShoesPanelPrice v-else-if="tab === 'price'" v-model:form="form" :errors="errors" :changed="editor.changed.value" :live="editor.live.value" :busy="editor.busy.value" @verify="editor.verifyToday($event, 'price_checked_at')" />
    <AdminShoesPanelLearned v-else-if="tab === 'review'" v-model:form="form" :errors="errors" :changed="editor.changed.value" :criteria="editor.loaded.value?.criteria ?? []" @media="editor.remember" />
  </template>
</template>
