<script setup lang="ts">
import type { Component } from 'vue'

/** One-row empty state of a card (the pattern of Inicio, README §16.6). */
defineProps<{ icon: Component; title: string; text: string; link?: { to: string; label: string }; links?: { to: string; label: string }[]; linksLabel?: string }>()
</script>

<template>
  <div class="flex items-start gap-3 py-1">
    <span class="grid size-8 flex-none place-items-center rounded-lg bg-adm-subtle text-adm-meta" aria-hidden="true"><component :is="icon" class="size-4" /></span>
    <div class="min-w-0">
      <p class="text-[13px] leading-5 font-medium">{{ title }}</p>
      <p class="max-w-[52ch] text-xs text-adm-meta">
        {{ text }}
        <template v-if="links?.length">
          {{ linksLabel }}
          <template v-for="(l, i) in links" :key="l.to"><template v-if="i"> · </template><NuxtLink :to="l.to" class="underline underline-offset-2 hover:text-adm-fg">{{ l.label }}</NuxtLink></template>
        </template>
        <NuxtLink v-if="link" :to="link.to" class="underline underline-offset-2 hover:text-adm-fg">{{ link.label }}</NuxtLink>
      </p>
    </div>
  </div>
</template>
