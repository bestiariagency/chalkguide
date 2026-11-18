/** Files dragged over the page: `over` while dragging files; `onFiles` gets what is dropped. */
export function useFileDrop(onFiles: (files: File[]) => void) {
  const over = ref(false)
  const hasFiles = (e: DragEvent) => !!e.dataTransfer && [...e.dataTransfer.types].includes('Files')
  const enter = (e: DragEvent) => {
    if (!hasFiles(e)) return
    e.preventDefault()
    over.value = true
  }
  const leave = (e: DragEvent) => {
    // relatedTarget null = left the window
    if (!e.relatedTarget) over.value = false
  }
  const drop = (e: DragEvent) => {
    if (!hasFiles(e)) return
    e.preventDefault()
    over.value = false
    onFiles([...(e.dataTransfer?.files ?? [])])
  }
  onMounted(() => {
    window.addEventListener('dragenter', enter)
    window.addEventListener('dragover', enter)
    window.addEventListener('dragleave', leave)
    window.addEventListener('drop', drop)
  })
  onBeforeUnmount(() => {
    window.removeEventListener('dragenter', enter)
    window.removeEventListener('dragover', enter)
    window.removeEventListener('dragleave', leave)
    window.removeEventListener('drop', drop)
  })
  return { over }
}
