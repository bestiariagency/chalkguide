<script setup lang="ts">
/**
 * Single-line text field (also numbers/urls/email). `prefix`/`suffix` render affixes ("/blog/",
 * "€"); `max` (+ optional `ideal`) adds the counter. v-model is a string.
 */
const props = withDefaults(
  defineProps<{
    label: string
    help?: string
    error?: string
    required?: boolean
    changed?: boolean
    lang?: 'ES' | 'EN'
    prefix?: string
    suffix?: string
    type?: 'text' | 'email' | 'url' | 'tel' | 'number' | 'search' | 'date' | 'time'
    inputmode?: 'text' | 'decimal' | 'numeric' | 'email' | 'url' | 'tel'
    placeholder?: string
    max?: number
    /** Hard limit on typing, without a counter (postal code, phone). */
    maxlength?: number
    ideal?: number
    /** SEO limits: title ideal 60 / max 70, description ideal 155 / max 160. */
    seo?: 'title' | 'description'
    mono?: boolean
    readonly?: boolean
    disabled?: boolean
    name?: string
    autocomplete?: string
  }>(),
  { type: 'text', help: undefined, changed: false, error: undefined, lang: undefined, prefix: undefined, suffix: undefined, inputmode: undefined, placeholder: undefined, max: undefined, maxlength: undefined, ideal: undefined, seo: undefined, name: undefined, autocomplete: undefined },
)
const model = defineModel<string>({ default: '' })
const emit = defineEmits<{ blur: [event: FocusEvent] }>()
const limits = computed(() => (props.seo ? SEO_LIMITS[props.seo] : { max: props.max, ideal: props.ideal }))
const affixed = computed(() => !!props.prefix || !!props.suffix)
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
    <div
      v-if="affixed"
      :class="[
        admInput,
        'flex items-center overflow-hidden px-0 focus-within:border-adm-acc focus-within:ring-[3px] focus-within:ring-adm-acc/20',
        invalid && admInputInvalid,
        readonly && 'border-adm-line-strong bg-adm-subtle',
      ]"
    >
      <span v-if="prefix" class="flex h-full items-center border-r border-adm-line-strong bg-adm-subtle pr-2 pl-2.5 font-mono text-xs whitespace-nowrap text-adm-meta">{{ prefix }}</span>
      <input
        :id="id"
        v-model="model"
        data-adm-inner
        :type="type"
        :inputmode="inputmode"
        :placeholder="placeholder"
        :maxlength="maxlength"
        :readonly="readonly"
        :disabled="disabled"
        :name="name"
        :autocomplete="autocomplete"
        :aria-invalid="invalid || undefined"
        :aria-describedby="describedby"
        :aria-required="required || undefined"
        :class="['h-full min-w-0 flex-1 bg-transparent px-2.5 outline-none placeholder:text-adm-muted', mono && 'font-mono text-[13px]']"
        @blur="emit('blur', $event)"
      />
      <span v-if="suffix" class="pr-2.5 text-xs text-adm-meta">{{ suffix }}</span>
    </div>
    <input
      v-else
      :id="id"
      v-model="model"
      :type="type"
      :inputmode="inputmode"
      :placeholder="placeholder"
      :maxlength="maxlength"
      :readonly="readonly"
      :disabled="disabled"
      :name="name"
      :autocomplete="autocomplete"
      :aria-invalid="invalid || undefined"
      :aria-describedby="describedby"
      :aria-required="required || undefined"
      :class="[admInput, invalid && admInputInvalid, mono && 'font-mono text-[13px]']"
      @blur="emit('blur', $event)"
    />
  </AdminField>
</template>
