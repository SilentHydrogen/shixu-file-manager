import './blob.js';
import 'formdata-polyfill/formdata.min.js';
import http from '@ohos.net.http';
import util from '@ohos.util';
import url from '@ohos.url';
import { Headers, Request, Response } from 'whatwg-fetch';
import { ReadableStream } from 'web-streams-polyfill/ponyfill/es2018';
import { AbortController, AbortSignal } from 'abort-controller/dist/abort-controller.mjs';

class TextEncoder {
  encode(value = '') { return new util.TextEncoder().encodeInto(value); }
}
class TextDecoder {
  constructor(label = 'utf-8') { this.decoder = util.TextDecoder.create(label); }
  decode(value = new Uint8Array(), options = {}) {
    const bytes = value instanceof ArrayBuffer ? new Uint8Array(value) : value;
    return this.decoder.decodeToString(bytes, { stream: !!options.stream });
  }
}

// These are web-platform primitives needed by the unmodified SDK, not LLM protocol adapters.
export function installPlatform() {
  Object.assign(globalThis, { Headers, Request, Response, ReadableStream, AbortController, AbortSignal,
    TextEncoder, TextDecoder, URL: url.URL, URLSearchParams: url.URLSearchParams });
  if (!globalThis.structuredClone) globalThis.structuredClone = value => JSON.parse(JSON.stringify(value));
  globalThis.fetch = harmonyFetch;
}

async function harmonyFetch(input, init = {}) {
  const request = http.createHttp();
  const signal = init.signal;
  const abort = () => request.destroy();
  if (signal?.aborted) { request.destroy(); throw new Error('请求已取消'); }
  signal?.addEventListener('abort', abort, { once: true });
  try {
    const headers = {};
    new Headers(init.headers).forEach((value, name) => { headers[name] = value; });
    // SDK owns SSE parsing. Buffering the HTTP body here avoids recreating any provider protocol.
    const result = await request.request(String(input), {
      method: init.method || 'GET', header: headers, extraData: init.body,
      expectDataType: http.HttpDataType.ARRAY_BUFFER, connectTimeout: 30000, readTimeout: 60000,
      usingCache: false, maxLimit: 8 * 1024 * 1024
    });
    if (signal?.aborted) throw new Error('请求已取消');
    const bytes = typeof result.result === 'string' ? new TextEncoder().encode(result.result) : new Uint8Array(result.result);
    const responseHeaders = {};
    for (const [name, value] of Object.entries(result.header || {})) {
      if (name.toLowerCase() !== 'set-cookie') responseHeaders[name] = String(value);
    }
    const response = new Response(bytes.buffer, { status: result.responseCode, headers: responseHeaders });
    Object.defineProperty(response, 'body', { value: new ReadableStream({ start(controller) {
      controller.enqueue(bytes); controller.close();
    } }) });
    return response;
  } catch (error) {
    const code = error?.code;
    const messages = { 201: '网络权限不足（201）', 2300006: '域名解析失败（2300006）',
      2300007: '无法连接提供商（2300007）', 2300028: '提供商响应超时（2300028）', 2300060: '证书校验失败（2300060）' };
    // SDK may wrap this error. Never expose raw response bodies or credentials.
    throw new Error(signal?.aborted ? '请求已取消' : messages[code] || '无法连接提供商，请检查手机网络和 API 地址');
  } finally { signal?.removeEventListener('abort', abort); request.destroy(); }
}

// Run before modules importing SDK dependencies execute their module initializers.
installPlatform();
