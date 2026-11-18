<script setup lang="ts">
import { FilePenLine, Languages, UserX } from 'lucide-vue-next'

/** «Cómo funciona la firma»: where it is set, what «EN completo» means and what deleting does. Beside the list on xl, below it otherwise. */
const points = [
  { icon: FilePenLine, title: 'Se asigna en el artículo', text: 'Editor → Ajustes del artículo → «Autor». En un publicado, el cambio va como cualquier otro: por «Publicar cambios».' },
  { icon: Languages, title: 'EN completo', text: 'Con rol y bio en inglés. Si falta alguno, en /en la firma sale con lo que haya.' },
  { icon: UserX, title: 'Al eliminar un autor', text: 'Sus artículos pasan a firmarlos tú, también los publicados y al momento. Su foto se queda en Medios.' },
]
</script>

<template>
  <aside :class="[admCard, 'min-w-0 space-y-3 p-4 text-sm']" aria-labelledby="h-how">
    <h2 id="h-how" class="text-sm font-semibold">Cómo funciona la firma</h2>
    <ul class="space-y-3">
      <li v-for="p in points" :key="p.title" class="flex gap-3">
        <span class="grid size-7 flex-none place-items-center rounded-md bg-adm-subtle text-adm-meta"><component :is="p.icon" class="size-4" aria-hidden="true" /></span>
        <span><span class="block font-medium">{{ p.title }}</span><span class="block text-xs text-adm-meta">{{ p.text }}</span></span>
      </li>
    </ul>
    <p class="border-t border-adm-line pt-3 text-xs text-adm-meta">No hay página pública por autor: la firma enlaza a «Sobre mí» solo cuando el autor eres tú.</p>
  </aside>
</template>
