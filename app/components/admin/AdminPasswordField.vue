<script setup lang="ts">
import { Eye, EyeOff } from 'lucide-vue-next'

/** Password field with show/hide. `autocomplete`: `current-password` or `new-password`. */
withDefaults(
  defineProps<{
    label: string
    help?: string
    error?: string
    autocomplete?: 'current-password' | 'new-password'
    readonly?: boolean
    required?: boolean
  }>(),
  { help: undefined, error: undefined, autocomplete: 'current-password' },
)
const model = defineModel<string>({ default: '' })
const shown = ref(false)
</script>

<template>
  <AdminField v-slot="{ id, describedby, invalid }" :label="label" :help="help" :error="error" :required="required">
    <div
      :class="[
        admInput,
        'flex items-center overflow-hidden px-0 focus-within:border-adm-acc focus-within:ring-[3px] focus-within:ring-adm-acc/20',
        invalid && admInputInvalid,
      ]"
    >
      <input
        :id="id"
        v-model="model"
        data-adm-inner
        :type="shown ? 'text' : 'password'"
        :autocomplete="autocomplete"
        :readonly="readonly"
        :aria-invalid="invalid || undefined"
        :aria-describedby="describedby"
        class="h-full min-w-0 flex-1 bg-transparent px-2.5 outline-none placeholder:text-adm-muted"
      />
      <button
        type="button"
        :class="[admIconBtn, 'mr-0.5 size-7! max-md:size-10!']"
        :aria-label="shown ? 'Ocultar contraseña' : 'Mostrar contraseña'"
        :aria-pressed="shown"
        @click="shown = !shown"
      >
        <EyeOff v-if="shown" aria-hidden="true" />
        <Eye v-else aria-hidden="true" />
      </button>
    </div>
  </AdminField>
</template>
