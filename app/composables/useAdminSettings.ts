import type { Database } from '~/types/database.types'
import { fetchSettings, updateSettings } from '~/services/admin/settings'
import type { AdminMedia } from '~/utils/admin-media'
import { STAT_MAX_ROWS } from '~/utils/admin-author-stats'
import { columnOf, settingsChangedFields, settingsFormFromRow, SETTING_AUTHOR_PHOTO, SETTING_OG, settingsPatch, settingsSections, type SettingsForm } from '~/utils/admin-settings'
import { settingsColumnLabel, settingsColumnValue } from '~/utils/admin-settings-conflict'
import { blockingFields, errorIsChanged, OG_ALT_MESSAGE, PHOTO_ALT_MESSAGE, settingsCheckErrors, settingsFailure, validateSettings } from '~/utils/admin-settings-check'

const LEAVE = 'Tienes cambios sin guardar en Ajustes. ¿Salir sin guardarlos?'

/** Focuses (and scrolls to) the control named like a field id. */
export function focusSettingsField(id: string) {
  const el = document.querySelector<HTMLElement>(`[name="${id}"]`)
  el?.scrollIntoView({ block: 'center', behavior: 'smooth' })
  el?.focus({ preventScroll: true })
}

/**
 * Settings screen (F6.17): loaded row, local form, changed fields, client validation, atomic save
 * (`admin_update_settings`) and the failures of the database: conflict (PT409), CHECK (23514),
 * missing alt on the OG image (PT422). No draft: saving is immediate.
 */
export function useAdminSettings() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const data = useAsyncData('admin-settings', () => fetchSettings(client), { server: false })
  const loaded = computed(() => data.data.value ?? undefined)

  const form = ref<SettingsForm>()
  const og = ref<AdminMedia | null>(null)
  const authorPhoto = ref<AdminMedia | null>(null)
  const attempted = ref(false)
  const busy = ref(false)
  const serverErrors = ref<Record<string, string>>({})
  /** Sections another session changed since this screen loaded (nothing was saved). */
  const conflict = ref<string[]>()
  /** Columns the server rejected (all the changed ones when it does not say). */
  const conflictColumns = ref<string[]>([])
  /** Server's current values of those columns, once «Ver la otra versión» is pressed. */
  const theirs = ref<{ label: string; value: string }[] | null>(null)

  watch(loaded, (value) => {
    form.value = value ? settingsFormFromRow(value.row) : undefined
    og.value = value?.og ?? null
    authorPhoto.value = value?.authorPhoto ?? null
    attempted.value = false
    serverErrors.value = {}
    conflict.value = undefined
    theirs.value = null
  }, { immediate: true })
  watch(form, () => { serverErrors.value = {} }, { deep: true })

  const changed = computed(() => (form.value && loaded.value ? settingsChangedFields(form.value, loaded.value.row) : []))
  const dirty = computed(() => changed.value.length > 0)
  const errors = computed(() => (form.value ? validateSettings(form.value, og.value, authorPhoto.value) : {}))
  /** Errors shown on screen: of fields already touched (or all after a save attempt) plus the database's. */
  const shown = computed(() => {
    const out: Record<string, string> = {}
    for (const [id, message] of Object.entries(errors.value)) if (attempted.value || errorIsChanged(id, changed.value)) out[id] = message
    return { ...out, ...serverErrors.value }
  })
  const consentChanged = computed(() => changed.value.some((id) => id.startsWith('newsletter_consent_text_')))

  function selectOg(media: AdminMedia | null) {
    if (!form.value) return
    og.value = media
    form.value.default_og_media_id = media?.id ?? null
  }
  function selectAuthorPhoto(media: AdminMedia | null) {
    if (!form.value) return
    authorPhoto.value = media
    form.value.author_photo_media_id = media?.id ?? null
  }
  /** «En números»: adds an empty row (max 2); removing one offers «Deshacer» in a toast. */
  function addStat() {
    if (form.value && form.value.author_stats.length < STAT_MAX_ROWS) form.value.author_stats.push({ value: '', label_es: '', label_en: '' })
  }
  function removeStat(index: number) {
    const [row] = form.value?.author_stats.splice(index, 1) ?? []
    if (!row) return
    success({ message: 'Cifra quitada', action: { label: 'Deshacer', run: () => form.value?.author_stats.splice(index, 0, row) } })
  }
  function discard() {
    if (conflict.value) {
      void reload()
      return
    }
    if (loaded.value) {
      form.value = settingsFormFromRow(loaded.value.row)
      og.value = loaded.value.og
      authorPhoto.value = loaded.value.authorPhoto
    }
    attempted.value = false
    conflict.value = undefined
  }
  const reload = () => data.refresh()

  async function viewTheirs() {
    try {
      const fresh = await fetchSettings(client)
      theirs.value = conflictColumns.value.map((c) => ({ label: settingsColumnLabel(c), value: settingsColumnValue(fresh, c) }))
    } catch {
      toastError('No se ha podido cargar la otra versión. Inténtalo de nuevo.')
    }
  }
  const keepMine = () => save(true)

  async function save(retryOnNewBase = false) {
    const current = loaded.value
    if (!form.value || !current || busy.value || !dirty.value) return
    attempted.value = true
    const blocking = blockingFields(changed.value, errors.value)
    if (blocking.length) return reportInvalid(blocking)
    busy.value = true
    try {
      const { changes, base } = settingsPatch(form.value, current.row, changed.value)
      if (retryOnNewBase) {
        // Conflicting columns: same new values, but against what the server has now. The rest keep their base.
        const fresh = await fetchSettings(client)
        const ids = changed.value.filter((id) => conflictColumns.value.includes(columnOf(id)))
        const patch = settingsPatch(form.value, fresh.row, ids)
        Object.assign(changes, patch.changes)
        Object.assign(base, patch.base)
      }
      const saved = await updateSettings(client, changes, base)
      await data.refresh()
      const bumped = saved.consent_version > current.row.consent_version
      success(bumped ? `Ajustes guardados · nueva versión ${saved.consent_version} del texto de consentimiento` : 'Ajustes guardados')
    } catch (e) {
      fail(e)
    } finally {
      busy.value = false
    }
  }

  function reportInvalid(ids: string[]) {
    const first = ids[0]!
    toastError({
      message: ids.length === 1
        ? 'Hay 1 error que impide guardar: revisa el campo marcado.'
        : `Hay ${ids.length} errores que impiden guardar: revisa los campos marcados.`,
      action: { label: ids.length === 1 ? 'Ir al campo' : 'Ir al primero', run: () => focusSettingsField(first) },
    })
    focusSettingsField(first)
  }

  function fail(e: unknown) {
    const failure = settingsFailure(e)
    if (failure.kind === 'conflict') {
      conflictColumns.value = failure.keys.length ? failure.keys : [...new Set(changed.value.map(columnOf))]
      conflict.value = settingsSections(conflictColumns.value)
      theirs.value = null
      toastError('No se ha guardado nada: otra sesión cambió estos ajustes antes que tú.')
    } else if (failure.kind === 'check' && form.value) {
      const mapped = settingsCheckErrors(failure.constraint, form.value)
      if (mapped) {
        serverErrors.value = mapped
        return reportInvalid(Object.keys(mapped))
      }
      toastError('Algún valor no es válido. Revisa los campos y vuelve a guardar.')
    } else if (failure.kind === 'og-alt') {
      const photo = changed.value.includes(SETTING_AUTHOR_PHOTO) && !changed.value.includes(SETTING_OG)
      serverErrors.value = photo ? { [SETTING_AUTHOR_PHOTO]: PHOTO_ALT_MESSAGE } : { [SETTING_OG]: OG_ALT_MESSAGE }
      reportInvalid(Object.keys(serverErrors.value))
    } else if (failure.kind === 'forbidden') {
      toastError('Tu cuenta no tiene permiso para cambiar los ajustes.')
    } else {
      toastError({ message: 'No se han podido guardar los ajustes. Inténtalo de nuevo.', action: { label: 'Reintentar', run: () => void save() } })
    }
  }

  // Leaving with unsaved changes: browser reload/close and in-app navigation.
  const beforeUnload = (event: BeforeUnloadEvent) => {
    if (dirty.value) event.preventDefault()
  }
  onMounted(() => window.addEventListener('beforeunload', beforeUnload))
  onBeforeUnmount(() => window.removeEventListener('beforeunload', beforeUnload))
  onBeforeRouteLeave(() => !dirty.value || window.confirm(LEAVE))

  return { data, loaded, form, og, authorPhoto, errors: shown, changed, dirty, busy, conflict, theirs, consentChanged, save, discard, reload, selectOg, selectAuthorPhoto, addStat, removeStat, viewTheirs, keepMine }
}
