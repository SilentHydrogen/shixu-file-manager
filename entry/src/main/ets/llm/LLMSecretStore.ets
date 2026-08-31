import { huks } from '@kit.UniversalKeystoreKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

const KEY_ALIAS: string = 'shixu_llm_api_key'
const AAD: string = 'shixu-file-manager-llm'
const AUTH_TAG_LENGTH: number = 16

function bytes(value: string): Uint8Array {
  const result: number[] = []
  for (const character of value) {
    const code: number = character.codePointAt(0) ?? 0
    if (code <= 0x7f) result.push(code)
    else if (code <= 0x7ff) result.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f))
    else if (code <= 0xffff) result.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f))
    else result.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f))
  }
  return new Uint8Array(result)
}
function stringValue(value: Uint8Array): string {
  let result: string = ''
  let index: number = 0
  while (index < value.length) {
    const first: number = value[index]
    if (first < 0x80) {
      result += String.fromCharCode(first)
      index += 1
    } else if (first < 0xe0) {
      const code: number = ((first & 0x1f) << 6) | (value[index + 1] & 0x3f)
      result += String.fromCharCode(code)
      index += 2
    } else if (first < 0xf0) {
      const code: number = ((first & 0x0f) << 12) | ((value[index + 1] & 0x3f) << 6) | (value[index + 2] & 0x3f)
      result += String.fromCharCode(code)
      index += 3
    } else {
      const code: number = ((first & 0x07) << 18) | ((value[index + 1] & 0x3f) << 12) | ((value[index + 2] & 0x3f) << 6) |
        (value[index + 3] & 0x3f)
      const base: number = code - 0x10000
      result += String.fromCharCode(0xd800 + (base >> 10), 0xdc00 + (base & 0x3ff))
      index += 4
    }
  }
  return result
}
function baseProperties(purpose: number): huks.HuksParam[] {
  return [
    { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
    { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_128 },
    { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose }
  ]
}
async function ensureKey(): Promise<void> {
  try {
    await huks.generateKeyItem(KEY_ALIAS, { properties: baseProperties(
      huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT) })
  } catch (error) {
    // Existing alias is expected after first launch.
  }
}
export async function encryptSecret(secret: string): Promise<string> {
  await ensureKey()
  const nonce: Uint8Array = cryptoFramework.createRandom().generateRandomSync(12).data
  const properties: huks.HuksParam[] = [
    ...baseProperties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT),
    { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
    { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
    { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: bytes(AAD) }
  ]
  const session = await huks.initSession(KEY_ALIAS, { properties: properties })
  const result = await huks.finishSession(session.handle, { properties: properties, inData: bytes(secret) })
  const encrypted: Uint8Array = result.outData as Uint8Array
  return JSON.stringify({ nonce: Array.from(nonce), data: Array.from(encrypted) })
}
export async function decryptSecret(payload: string): Promise<string> {
  const stored: Record<string, Object> = JSON.parse(payload) as Record<string, Object>
  const nonce: Uint8Array = new Uint8Array(stored.nonce as number[])
  const encrypted: Uint8Array = new Uint8Array(stored.data as number[])
  const properties: huks.HuksParam[] = [
    ...baseProperties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT),
    { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
    { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
    { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: bytes(AAD) },
    { tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: encrypted.slice(encrypted.length - AUTH_TAG_LENGTH) }
  ]
  const session = await huks.initSession(KEY_ALIAS, { properties: properties })
  const result = await huks.finishSession(session.handle, {
    properties: properties,
    inData: encrypted.slice(0, encrypted.length - AUTH_TAG_LENGTH)
  })
  return stringValue(result.outData as Uint8Array)
}
export async function deleteSecret(): Promise<void> {
  await huks.deleteKeyItem(KEY_ALIAS, { properties: [] })
}
