<script setup lang="ts">
/** "Nuevo" sheet: bottom sheet on mobile, modal on desktop. Entries come from `ADMIN_CREATE`. */
const { newOpen } = useAdminPalette()

function go(to: string) {
  newOpen.value = false
  void navigateTo(to)
}
</script>

<template>
  <AdminModal v-model:open="newOpen" title="Crear" description="¿Qué quieres crear?">
    <ul class="grid gap-1 sm:grid-cols-2">
      <li v-for="item in ADMIN_CREATE" :key="item.label">
        <button
          type="button"
          class="flex min-h-11 w-full items-center gap-3 rounded-lg border border-adm-line px-3 py-2 text-left hover:border-adm-line-strong hover:bg-adm-subtle"
          @click="go(item.to)"
        >
          <component :is="item.icon" class="size-4 flex-none text-adm-acc" aria-hidden="true" />
          <span>
            <span class="block text-[13px] font-medium">{{ item.label }}</span>
            <span class="block text-xs text-adm-meta">{{ item.description }}</span>
          </span>
        </button>
      </li>
    </ul>
  </AdminModal>
</template>
