export const MAX_UPLOAD_BYTES: number = 100 * 1024 * 1024
export const MAX_UPLOAD_CHARACTERS: number = 8000
export const UPLOAD_RATIO: number = 0.2

export function clampUploadContent(content: string, byteLength: number = content.length): string {
  if (byteLength <= 0) return ''
  const ratioLength: number = Math.ceil(content.length * UPLOAD_RATIO)
  return content.substring(0, Math.min(ratioLength, MAX_UPLOAD_CHARACTERS))
}

export function canProcessFile(byteLength: number): boolean {
  return byteLength >= 0 && byteLength <= MAX_UPLOAD_BYTES
}
