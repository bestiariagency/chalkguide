<script setup lang="ts">
/** Internal showcase of the panel components (admin only, noindex) for design review. */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Componentes')
const { openPalette, openNew } = useAdminPalette()

const sections = [
  { id: 'tablas', title: 'Tabla de datos' },
  { id: 'formularios', title: 'Formularios' },
  { id: 'overlays', title: 'Modales y confirmaciones' },
  { id: 'varios', title: 'Insignias, avisos y orden' },
  { id: 'atajos', title: 'Paleta y hoja Nuevo' },
]
</script>

<template>
  <div>
  <AdminPageBar title="Componentes" desktop-only />
  <div class="mx-auto max-w-[1200px] space-y-10 px-4 py-6 md:px-6">
    <header>
      <h1 class="text-xl leading-7 font-semibold tracking-tight">Componentes del panel</h1>
      <p class="mt-1 text-[13px] text-adm-meta">Datos de ejemplo. Solo para revisar el diseño; no guarda nada.</p>
      <nav aria-label="Secciones de esta página" class="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-[13px]">
        <a v-for="s in sections" :key="s.id" :href="`#${s.id}`" class="underline underline-offset-2 max-md:py-2">{{ s.title }}</a>
      </nav>
    </header>
    <section id="tablas" aria-labelledby="h-tablas">
      <h2 id="h-tablas" class="mb-3 text-base font-semibold">Tabla de datos</h2>
      <AdminDemoTable />
    </section>
    <section id="formularios" aria-labelledby="h-forms">
      <h2 id="h-forms" class="mb-3 text-base font-semibold">Formularios</h2>
      <AdminDemoForms />
    </section>
    <section id="overlays" aria-labelledby="h-ov">
      <h2 id="h-ov" class="mb-3 text-base font-semibold">Modales y confirmaciones</h2>
      <AdminDemoOverlays />
    </section>
    <section id="varios" aria-labelledby="h-var">
      <h2 id="h-var" class="mb-3 text-base font-semibold">Insignias, avisos y orden</h2>
      <AdminDemoMisc />
    </section>
    <section id="atajos" aria-labelledby="h-at">
      <h2 id="h-at" class="mb-3 text-base font-semibold">Paleta y hoja Nuevo</h2>
      <div class="flex flex-wrap items-center gap-2">
        <button type="button" :class="admBtnGhost" @click="openPalette">Abrir paleta <kbd :class="admKbd">⌘K</kbd></button>
        <button type="button" :class="admBtnGhost" @click="openNew">Abrir hoja «Nuevo»</button>
      </div>
    </section>
  </div>
  </div>
</template>
