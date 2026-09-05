import buffer from '@ohos.buffer';
// Native Harmony Blob enables the standards-based FormData polyfill required by OpenAI SDK type checks.
globalThis.Blob = buffer.Blob;
