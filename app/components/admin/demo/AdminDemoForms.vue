<script setup lang="ts">
/** Showcase: form controls with their validation states. */
const name = ref('La Paret de Gràcia')
const price = ref('15,5O')
const web = ref('https://laparet')
const title = ref('Dónde escalar en Barcelona cuando llueve: 9 rocódromos')
const description = ref('Nueve rocódromos a 30 minutos en metro y para qué sirve cada uno cuando la roca está mojada: bloque, cuerda, precios y horas tranquilas para ir.')
const articleTitle = ref('Rocódromos para ir solo en Barcelona')
const slug = ref('')
const publishedSlug = ref('donde-escalar-en-barcelona-cuando-llueve')
const summaryEs = ref('Rocódromo de cuerda con vías de hasta 15 metros y autobelays.')
const summaryEn = ref('Rope gym with routes up to 15 metres and auto-belays.')
const category = ref<string | undefined>('progresion')
const featured = ref(true)
const hidden = ref(false)
const options = [
  { value: 'empezar', label: 'Empezar a escalar' },
  { value: 'progresion', label: 'Progresión y cuidado' },
  { value: 'material', label: 'Material' },
  { value: 'costes', label: 'Costes', disabled: true },
]
const priceError = computed(() => (/^\d+(,\d{1,2})?$/.test(price.value) ? '' : 'Escribe solo cifras, con coma para los decimales (p. ej. 15,50).'))
</script>

<template>
  <div class="grid gap-6 lg:grid-cols-2">
    <div class="space-y-4">
      <AdminTextField v-model="name" label="Nombre" required />
      <AdminTextField v-model="web" label="Web oficial" type="url" help="Con https://. Se muestra como enlace en la ficha." />
      <AdminTextField v-model="price" label="Precio de entrada de día" suffix="€" inputmode="decimal" :error="priceError" />
      <AdminTextField label="Teléfono" model-value="Se rellena desde Google Places (próximamente)" disabled />
      <AdminSelect v-model="category" label="Categoría" :options="options" required help="Se añaden al final del orden de esa categoría." />
      <AdminSwitch v-model="featured" label="Destacado en el blog" help="Aparece en la portada del blog." />
      <AdminSwitch v-model="hidden" label="Ocultar la ficha" />
    </div>
    <div class="space-y-4">
      <AdminTextField v-model="title" label="Título SEO" seo="title" help="Ideal 50–60. Vacío: se usa el título del artículo." />
      <AdminTextArea v-model="description" label="Descripción SEO" seo="description" :rows="3" />
      <AdminTextField v-model="articleTitle" label="Título del artículo" required />
      <AdminSlugField v-model="slug" prefix="/blog/" :source="articleTitle" available />
    </div>
    <div class="space-y-4 lg:col-span-2">
      <h3 class="text-sm font-semibold">URL de algo publicado</h3>
      <AdminSlugField v-model="publishedSlug" prefix="/blog/" published />
      <h3 class="pt-2 text-sm font-semibold">Par ES / EN (lado a lado cuando el contenedor mide 672 px o más)</h3>
      <AdminLangPair legend="Resumen en español e inglés">
        <template #es><AdminTextArea v-model="summaryEs" label="Resumen" lang="ES" :max="400" /></template>
        <template #en><AdminTextArea v-model="summaryEn" label="Resumen" lang="EN" :max="400" /></template>
      </AdminLangPair>
    </div>
  </div>
</template>
