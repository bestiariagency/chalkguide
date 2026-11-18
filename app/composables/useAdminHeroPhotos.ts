import type { Database } from '~/types/database.types'
import { fetchHeroPhotos, setHeroPhoto, type HeroSlot } from '~/services/admin/hero-photos'
import { altRefusal, mediaLink } from '~/utils/content-alt'
import type { AdminMedia } from '~/utils/admin-media'

/** Hero photos of the home (D41): saved at once on choosing or removing. */
export function useAdminHeroPhotos() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const list = useAsyncData('admin-hero-photos', () => fetchHeroPhotos(client), { server: false })
  const photos = computed(() => list.data.value ?? [null, null])
  const busy = ref<HeroSlot | null>(null)

  function altError(media: AdminMedia) {
    const lang = !media.alt_es && !media.alt_en ? 'en español e inglés' : !media.alt_es ? 'en español' : 'en inglés'
    toastError({
      message: `La foto «${media.original_filename}» no tiene texto alternativo ${lang}. Añádelo en Medios y vuelve a elegirla.`,
      action: { label: 'Abrir en Medios', run: () => void navigateTo(mediaLink(media.id)) },
    })
  }

  async function save(slot: HeroSlot, media: AdminMedia | null) {
    if (media && (!media.alt_es || !media.alt_en)) return altError(media)
    if (busy.value !== null) return
    busy.value = slot
    try {
      await setHeroPhoto(client, slot, media?.id ?? null)
      success(media ? `Foto ${slot} guardada` : `Foto ${slot} quitada`)
      // useAsyncData never rejects: a failed reload lands in `list.error` (the block then offers «Reintentar»).
      await list.refresh()
      if (list.error.value) {
        toastError({ message: 'Se ha guardado, pero no se ha podido recargar la lista. Recarga la página para verla.', action: { label: 'Cerrar', run: () => {} } })
      }
    } catch (e) {
      if (media && altRefusal(e)) altError(media)
      else toastError({ message: 'No se ha podido guardar la foto. Inténtalo de nuevo.', action: { label: 'Cerrar', run: () => {} } })
    } finally {
      busy.value = null
    }
  }

  return { list, photos, busy, save }
}
