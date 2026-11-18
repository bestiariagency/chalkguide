import type { Database } from '~/types/database.types'
import { fetchTodayImport } from '~/services/admin/import'
import { madridParts } from '~/utils/admin-madrid'
import type { ItemInfo } from '~/utils/item-spec'

/** Filter "Importación de hoy" of the list (README §13.7): `?importacion=hoy`, with the items of the imports of today. */
export function useAdminImportFilter(info: ItemInfo) {
  const client = useSupabaseClient<Database>()
  const route = useRoute()
  const router = useRouter()
  const active = ref(route.query.importacion === 'hoy')
  const today = useAsyncData(`admin-import-today-${info.category}`, () => (active.value ? fetchTodayImport(client, info.category) : Promise.resolve(null)), { server: false, watch: [active] })
  const ids = computed(() => new Set(today.data.value?.ids ?? []))
  const label = computed(() => (today.data.value ? `Importación de hoy, ${madridParts(today.data.value.since).time} · ${today.data.value.ids.length}` : 'Importación de hoy'))

  function clear() {
    active.value = false
    const rest = Object.fromEntries(Object.entries(route.query).filter(([key]) => !['importacion', 'asignar', 'publicar'].includes(key)))
    void router.replace({ query: rest })
  }
  return { active, ids, label, loading: computed(() => today.status.value === 'pending'), clear }
}
