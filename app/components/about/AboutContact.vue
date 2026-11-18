<script setup lang="ts">
/** "Escríbeme" plate (§13.8). The page only mounts it when there is a contact_email. */
defineProps<{ email: string }>()
const { t } = useI18n()
</script>

<template>
  <section class="mx-auto max-w-page px-4 py-16 md:px-6 md:py-24" aria-labelledby="about-contact">
    <div class="grid items-end gap-x-6 gap-y-6 rounded-slab bg-elevated p-6 md:p-12 lg:grid-cols-12">
      <div class="lg:col-span-7">
        <h2 id="about-contact" class="text-title-2 font-medium">{{ t('about.contact') }}</h2>
        <p class="mt-4 max-w-[46ch] text-body-lg text-prose">{{ t('about.contactBody') }}</p>
      </div>
      <div class="flex flex-col items-start gap-3 lg:col-span-5 lg:items-end lg:justify-self-end">
        <UiButton :href="`mailto:${email}`" variant="ink" class="w-full sm:w-auto">{{ t('about.contact') }}</UiButton>
        <p class="font-mono text-caption text-meta">{{ email }}</p>
      </div>
    </div>
  </section>
</template>
