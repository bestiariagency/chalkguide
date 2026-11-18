<script setup lang="ts">
/** Group of boxes for a list column (recommended use, level): the stored order is always the order of `options`. */
const props = defineProps<{ label: string; options: readonly (readonly [string, string])[]; help?: string }>()
const model = defineModel<string[]>({ required: true })
const uid = useId()

function toggle(key: string, on: boolean) {
  const next = new Set(model.value)
  if (on) next.add(key)
  else next.delete(key)
  model.value = props.options.map(([k]) => k).filter((k) => next.has(k))
}
</script>

<template>
  <fieldset>
    <legend class="mb-1.5 text-xs font-medium">{{ label }}</legend>
    <div class="flex flex-wrap gap-2">
      <label v-for="[key, text] in options" :key="key" class="flex min-h-9 cursor-pointer items-center gap-2 rounded-lg border border-adm-line-strong bg-adm-elev px-3 py-1.5 text-sm has-[button[data-state=checked]]:border-adm-fg has-[button[data-state=checked]]:bg-adm-subtle has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-adm-acc max-md:min-h-11 [&_button:focus-visible]:outline-none [&_button:focus-visible]:ring-0">
        <AdminCheckbox :label="text" :model-value="model.includes(key)" @update:model-value="toggle(key, $event === true)" />{{ text }}
      </label>
    </div>
    <p v-if="help" :id="`${uid}-h`" class="mt-1.5 text-xs text-adm-meta">{{ help }}</p>
  </fieldset>
</template>
