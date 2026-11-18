/**
 * For form components with inheritAttrs: false: `class`/`style` go to the root wrapper
 * (layout), every other attribute (type, name, autocomplete…) goes to the native control.
 */
export function useSplitAttrs() {
  const attrs = useAttrs()
  const rootAttrs = computed(() => ({ class: attrs.class, style: attrs.style }))
  const controlAttrs = computed(() => {
    const { class: _class, style: _style, ...rest } = attrs
    return rest
  })
  return { rootAttrs, controlAttrs }
}
