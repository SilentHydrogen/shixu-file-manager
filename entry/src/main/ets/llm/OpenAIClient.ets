import { LLMProtocol } from './LLMTypes'

export function resolveLLMEndpoint(baseURL: string, protocol: LLMProtocol): string {
  const base = baseURL.trim().replace(/\/+$/, '')
  if (!/^https?:\/\/[^\s/?#]+(?:\/[^\s?#]*)?$/.test(base)) {
    throw new Error('请输入有效的 http:// 或 https:// API 地址，不要附带查询参数')
  }
  if ((base.endsWith('/responses') && protocol === 'chat_completions') ||
    (base.endsWith('/chat/completions') && protocol === 'responses')) {
    throw new Error('API 地址与协议不一致，请选择自动协议或修改地址')
  }
  if (base.endsWith('/chat/completions') || base.endsWith('/responses')) return base
  return `${base}/${protocol === 'responses' ? 'responses' : 'chat/completions'}`
}

export function describeLLMError(error: Object): string {
  const code = (error as Record<string, Object>).code
  if (code === 201) return '网络权限不足，请安装包含网络权限的新版应用（201）'
  if (code === 2300006) return '域名解析失败，请检查 API 地址和手机网络（2300006）'
  if (code === 2300007) return '无法连接提供商，请检查服务端口和手机网络（2300007）'
  if (code === 2300028) return '提供商响应超时，请稍后重试（2300028）'
  if (code === 2300060) return '证书校验失败，请检查提供商 HTTPS 证书（2300060）'
  if (error instanceof Error) return error.message
  return typeof code === 'number' ? `网络请求失败（${code}），请检查手机网络和提供商地址` : '请求失败，请稍后重试'
}
