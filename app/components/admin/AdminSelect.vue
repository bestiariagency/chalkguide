<script setup lang="ts">
import { SelectContent, SelectItem, SelectItemIndicator, SelectItemText, SelectPortal, SelectRoot, SelectTrigger, SelectValue, SelectViewport } from 'reka-ui'
import { Check, ChevronDown } from 'lucide-vue-next'

/** Select (Reka Select, keyboard and typeahead). v-model is the option `value` (undefined = none). */
defineProps<{
  label: string
  options: readonly AdminOption[]
  help?: string
  error?: string
  required?: boolean
  lang?: 'ES' | 'EN'
  placeholder?: string
  disabled?: boolean
  name?: string
  hideLabel?: boolean
}>()
const model = defineModel<string | undefined>()
</script>

<template>
  <AdminField v-slot="{ id, describedby, invalid }" :label="label" :help="help" :error="error" :required="required" :lang="lang" :hide-label="hideLabel">
    <SelectRoot v-model="model" :disabled="disabled" :name="name" :required="required">
      <SelectTrigger
        :id="id"
        :aria-invalid="invalid || undefined"
        :aria-describedby="describedby"
        :class="[admInput, 'flex items-center justify-between gap-2 text-left data-[placeholder]:text-adm-muted data-[disabled]:cursor-not-allowed data-[disabled]:border-adm-line-strong data-[disabled]:bg-adm-subtle data-[disabled]:text-adm-meta', invalid && admInputInvalid]"
      >
        <SelectValue :placeholder="placeholder ?? 'Elige una opción'" class="truncate" />
        <ChevronDown class="size-4 flex-none text-adm-muted" aria-hidden="true" />
      </SelectTrigger>
      <SelectPortal>
        <SelectContent
          position="popper"
          :side-offset="4"
          :class="[admPopover, 'admin w-(--reka-select-trigger-width) min-w-(--reka-select-trigger-width) font-sans']"
        >
          <SelectViewport class="max-h-72">
            <SelectItem
              v-for="option in options"
              :key="option.value"
              :value="option.value"
              :disabled="option.disabled"
              :class="[admMenuItem, 'cursor-pointer data-[disabled]:cursor-not-allowed data-[disabled]:opacity-45 data-[state=checked]:font-medium']"
            >
              <SelectItemText class="flex-1 truncate">{{ option.label }}</SelectItemText>
              <SelectItemIndicator><Check class="text-adm-acc!" aria-hidden="true" /></SelectItemIndicator>
            </SelectItem>
          </SelectViewport>
        </SelectContent>
      </SelectPortal>
    </SelectRoot>
  </AdminField>
</template>
