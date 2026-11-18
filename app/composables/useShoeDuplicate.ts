import type { SupabaseClient } from '@supabase/supabase-js'
import { shoeModelTaken } from '~/services/admin/items'
import type { Database } from '~/types/database.types'
import { SHOE_DUPLICATE_MESSAGE } from '~/utils/check-violation'
import type { ItemCategory } from '~/utils/item-spec'

/**
 * Marks brand and model while typing when another shoe already has the pair (rpc `shoe_model_taken`,
 * debounced). Does nothing for other categories. A failed lookup is ignored: the database still refuses on save.
 */
export function useShoeDuplicate(client: SupabaseClient<Database>, id: string, category: ItemCategory, form: Ref<{ brand?: string; model?: string } | null>) {
  const pair = computed(() => `${form.value?.brand?.trim() ?? ''}\n${form.value?.model?.trim() ?? ''}`)
  const settled = useDebouncedValue(pair, 500)
  const taken = ref('')

  if (category === 'shoe') {
    watch(settled, async (value) => {
      const [brand = '', model = ''] = value.split('\n')
      if (!brand || !model) {
        taken.value = ''
        return
      }
      try {
        taken.value = (await shoeModelTaken(client, brand, model, id)) ? value : ''
      } catch {
        taken.value = ''
      }
    })
  }

  const errors = computed<Record<string, string>>(() =>
    taken.value && taken.value === pair.value ? { brand: SHOE_DUPLICATE_MESSAGE, model: SHOE_DUPLICATE_MESSAGE } : ({} as Record<string, string>),
  )
  return { errors }
}
