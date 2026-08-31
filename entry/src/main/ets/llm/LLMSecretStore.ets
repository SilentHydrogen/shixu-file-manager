import { huks } from '@kit.UniversalKeystoreKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

const KEY_ALIAS: string = 'shixu_llm_api_key'
const AAD: string = 'shixu-file-manager-llm'
const NONCE_LENGTH: number = 12
const AUTH_TAG_LENGTH: number = 16

function textBytes(value: string): Uint8Array {
  const bytes: number[] = []
  for (let index: number = 0; index < value.length; index++) {
    bytes.push(value.charCodeAt(index) & 0xff)
  }
  return new Uint8Array(bytes)
}

function textValue(bytes: Uint8Array): string {
  let value: string = ''
  for (let index: number = 0; index < bytes.length; index++) {
    value += String.fromCharCode(bytes[index])
  }
  return value
}

function keyProperties(purpose: number): huks.HuksParam[] {
  return [
    { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
    { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_128 },
    { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose }
  ]
}

async function ensureKey(): Promise<void> {
  try {
    await huks.generateKeyItem(KEY_ALIAS, { properties: keyProperties(
      huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
    ) })
  } catch (error) {
    // Existing key is expected on subsequent launches. Encryption/decryption below
    // still reports an error when the alias is invalid or unavailable.
  }
}

export async function encryptSecret(secret: string): Promise<string> {
  await ensureKey()
  const nonce: Uint8Array = cryptoFramework.createRandom().generateRandomSync(NONCE_LENGTH).data
  const properties: huks.HuksParam[] = [
    ...keyProperties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT),
    { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
    { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
    { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: textBytes(AAD) }
  ]
  const session = await huks.initSession(KEY_ALIAS, { properties: properties })
  const encrypted = await huks.finishSession(session.handle, {
    properties: properties,
    inData: textBytes(secret)
  })
  return JSON.stringify({ nonce: Array.from(nonce), data: Array.from(encrypted.outData as Uint8Array) })
}

export async function decryptSecret(payload: string): Promise<string> {
  const stored: Record<string, Object> = JSON.parse(payload) as Record<string, Object>
  const nonce: Uint8Array = new Uint8Array(stored.nonce as number[])
  const encrypted: Uint8Array = new Uint8Array(stored.data as number[])
  const tag: Uint8Array = encrypted.slice(encrypted.length - AUTH_TAG_LENGTH)
  const cipher: Uint8Array = encrypted.slice(0, encrypted.length - AUTH_TAG_LENGTH)
  const properties: huks.HuksParam[] = [
    ...keyProperties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT),
    { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
    { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
    { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: textBytes(AAD) },
    { tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: tag }
  ]
  const session = await huks.initSession(KEY_ALIAS, { properties: properties })
  const decrypted = await huks.finishSession(session.handle, {
    properties: properties,
    inData: cipher
  })
  return textValue(decrypted.outData as Uint8Array)
}

export async function deleteSecret(): Promise<void> {
  await huks.deleteKeyItem(KEY_ALIAS, { properties: [] })
}
