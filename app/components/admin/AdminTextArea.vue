<script setup lang="ts">
/**
 * Textarea with optional counter. `max` is the hard limit (DB CHECK: over it the field is invalid),
 * `ideal` the recommended length. `seo="title" | "description"` applies the SEO limits (ideal 60 /
 * max 70 and ideal 155 / max 160).
 */
const props = withDefaults(
  defineProps<{
    label: string
    help?: string
    error?: string
    required?: boolean
    changed?: boolean
    lang?: 'ES' | 'EN'
    rows?: number
    placeholder?: string
    max?: number
    ideal?: number
    seo?: 'title' | 'description'
    readonly?: boolean
    disabled?: boolean
    name?: string
  }>(),
  { rows: 3, help: undefined, changed: false, error: undefined, lang: undefined, placeholder: undefined, max: undefined, ideal: undefined, seo: undefined, name: undefined },
)
const model = defineModel<string>({ default: '' })
const limits = computed(() => (props.seo ? SEO_LIMITS[props.seo] : { max: props.max, ideal: props.ideal }))
</script>

<template>
  <AdminField
    v-slot="{ id, describedby, invalid }"
    :label="label"
    :help="help"
    :error="error"
    :required="required"
    :changed="changed"
    :lang="lang"
    :count="limits.max ? model.length : undefined"
    :max="limits.max"
    :ideal="limits.ideal"
  >
    <textarea
      :id="id"
      v-model="model"
      :rows="rows"
      :placeholder="placeholder"
      :readonly="readonly"
      :disabled="disabled"
      :name="name"
      :aria-invalid="invalid || undefined"
      :aria-describedby="describedby"
      :aria-required="required || undefined"
      :class="[admInput, 'h-auto! resize-y py-[7px] leading-5 max-md:h-auto!', invalid && admInputInvalid]"
    />
  </AdminField>
</template>
