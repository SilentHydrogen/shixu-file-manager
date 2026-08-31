export function limitLeadingText(text: string, ratio: number = 0.2, maxCharacters: number = 8000): string {
  if (text.length === 0 || maxCharacters <= 0) return ''
  const safeRatio: number = Math.max(0, Math.min(1, ratio))
  const target: number = Math.min(Math.max(1, Math.ceil(text.length * safeRatio)), maxCharacters)
  return text.substring(0, target)
}

export function chunkText(text: string, chunkSize: number = 256, overlap: number = 32, maxChunks: number = 32): string[] {
  if (text.length === 0 || chunkSize <= 0 || maxChunks <= 0) return []
  const safeOverlap: number = Math.max(0, Math.min(overlap, chunkSize - 1))
  const step: number = chunkSize - safeOverlap
  const chunks: string[] = []
  let start: number = 0
  while (start < text.length && chunks.length < maxChunks) {
    const end: number = Math.min(start + chunkSize, text.length)
    chunks.push(text.substring(start, end))
    if (end >= text.length) break
    start += step
  }
  return chunks
}
