<script setup lang="ts">
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'

/** Pagination footer: range, page size (25/50/100) and previous/next. Page is 0-based. */
const props = defineProps<{ page: number; pageSize: number; total: number; disabled?: boolean }>()
const emit = defineEmits<{ 'update:page': [page: number]; 'update:pageSize': [size: number] }>()

const pages = computed(() => Math.max(1, Math.ceil(props.total / props.pageSize)))
const from = computed(() => (props.total === 0 ? 0 : props.page * props.pageSize + 1))
const to = computed(() => Math.min(props.total, (props.page + 1) * props.pageSize))
const sizeId = `size-${useId()}`
</script>

<template>
  <nav aria-label="Paginación" class="flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-adm-line px-3 py-2 text-[13px] text-adm-meta">
    <p class="whitespace-nowrap tabular-nums">{{ from }}–{{ to }} de {{ total }}</p>
    <div class="ml-auto flex items-center gap-2">
      <label :for="sizeId" class="whitespace-nowrap max-sm:sr-only">Filas por página</label>
      <select
        :id="sizeId"
        :value="pageSize"
        :disabled="disabled"
        :class="[admInput, 'w-auto! py-0 pr-2']"
        @change="emit('update:pageSize', Number(($event.target as HTMLSelectElement).value))"
      >
        <option v-for="size in ADMIN_PAGE_SIZES" :key="size" :value="size">{{ size }}</option>
      </select>
      <button type="button" :class="admIconBtn" aria-label="Página anterior" :disabled="disabled || page <= 0" @click="emit('update:page', page - 1)">
        <ChevronLeft aria-hidden="true" />
      </button>
      <span class="whitespace-nowrap tabular-nums">{{ page + 1 }} / {{ pages }}</span>
      <button type="button" :class="admIconBtn" aria-label="Página siguiente" :disabled="disabled || page >= pages - 1" @click="emit('update:page', page + 1)">
        <ChevronRight aria-hidden="true" />
      </button>
    </div>
  </nav>
</template>
