<script setup lang="ts">
import { CircleAlert } from 'lucide-vue-next'
import type { PageChecklistItem } from '~/utils/page-form'

/**
 * "No se ha publicado": banner with `role="alert"` and focus after a refused publication, with one link
 * to each thing to fix (D34 `#errores`) and the server's own message when it was the database that refused.
 */
defineProps<{ items: PageChecklistItem[]; message: string }>()
defineEmits<{ goto: [item: PageChecklistItem] }>()
const root = ref<HTMLElement>()
defineExpose({ focus: () => root.value?.focus() })
</script>

<template>
  <div class="px-4 pt-4 md:px-6">
    <div ref="root" tabindex="-1" role="alert" class="flex gap-2.5 rounded-lg bg-adm-danger-soft px-3 py-2.5 text-sm focus-visible:outline-2 focus-visible:outline-adm-danger">
      <CircleAlert class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" />
      <div>
        <b>{{ items.length ? `No se ha publicado: ${items.length === 1 ? 'hay 1 cosa' : `hay ${items.length} cosas`} que arreglar.` : 'No se ha publicado.' }}</b>
        <ul v-if="items.length" class="mt-1 list-disc space-y-0.5 pl-4">
          <li v-for="item in items" :key="item.key">
            <button v-if="item.target" type="button" class="text-left underline underline-offset-2 max-md:min-h-11" @click="$emit('goto', item)">{{ item.label }}: {{ item.hint ?? 'revísalo' }}</button>
            <template v-else>{{ item.label }}: {{ item.hint }}</template>
          </li>
        </ul>
        <p v-if="message" class="mt-1">{{ message }}</p>
      </div>
    </div>
  </div>
</template>
