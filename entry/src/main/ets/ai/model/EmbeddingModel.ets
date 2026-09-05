import { mindSporeLite } from '@kit.MindSporeLiteKit'
import { common } from '@kit.AbilityKit'
import util from '@ohos.util'

interface TokenizerModel { vocab: Record<string, number> }
interface TokenizerConfig { model: TokenizerModel }

export function tokenTensorData(values: number[], dtype: mindSporeLite.DataType): ArrayBuffer {
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_INT32) return new Int32Array(values).buffer
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_INT64) {
    return new BigInt64Array(values.map((value: number) => BigInt(value))).buffer
  }
  throw new Error(`Unsupported token tensor dtype: ${dtype}`)
}

/** Offline BGE-small-zh inference through HarmonyOS MindSpore Lite Kit. */
export class EmbeddingModel {
  static readonly EMBEDDING_DIM: number = 512
  static readonly MAX_TOKENS: number = 512
  private inferenceTail: Promise<void> = Promise.resolve()
  private loaded: boolean = false
  private model: mindSporeLite.Model | null = null
  private context: common.Context | null = null
  private vocabulary: Record<string, number> = {}
  private padTokenId: number = 0
  private clsTokenId: number = 101
  private sepTokenId: number = 102

  async loadModel(context?: common.Context): Promise<void> {
    if (this.loaded) return
    if (context !== undefined) this.context = context
    if (this.context === null) throw new Error('Embedding model requires UIAbilityContext')
    const tokenizerBytes = await this.context.resourceManager.getRawFileContent('models/tokenizer.json')
    const tokenizerText = util.TextDecoder.create('utf-8').decodeToString(tokenizerBytes)
    const tokenizer = JSON.parse(tokenizerText) as TokenizerConfig
    this.vocabulary = tokenizer.model.vocab
    this.padTokenId = this.vocabulary['[PAD]'] ?? 0
    this.clsTokenId = this.vocabulary['[CLS]'] ?? 101
    this.sepTokenId = this.vocabulary['[SEP]'] ?? 102
    const modelBytes = await this.context.resourceManager.getRawFileContent('models/bge-small-zh-v1.5-int8.ms')
    this.model = await mindSporeLite.loadModelFromBuffer(modelBytes.buffer)
    this.loaded = this.model !== null
    if (!this.loaded) throw new Error('Failed to load local BGE model')
    const inputs = this.model?.getInputs() ?? []
    console.info(`Local embedding inputs: ${inputs.map((input) => `${input.name}:${input.dtype}`).join(',')}`)
  }

  encode(text: string): Promise<number[]> {
    const next = this.inferenceTail.then(() => this.encodeSerial(text))
    this.inferenceTail = next.then(() => {}, () => {})
    return next
  }

  private async encodeSerial(text: string): Promise<number[]> {
    if (!this.loaded) await this.loadModel()
    if (this.model === null) throw new Error('Embedding model is not loaded')
    const inputs = this.model.getInputs()
    if (inputs.length === 0) throw new Error('BGE model has no inputs')
    const ids = this.tokenize(text)
    const mask = ids.map((id: number) => id === this.padTokenId ? 0 : 1)
    const types = new Array<number>(ids.length).fill(0)
    const values: number[][] = [ids, mask, types]
    for (let i = 0; i < inputs.length; i++) {
      const name = inputs[i].name.toLowerCase()
      let inputValues = values[Math.min(i, values.length - 1)]
      if (name.includes('input_ids')) inputValues = ids
      else if (name.includes('attention_mask')) inputValues = mask
      else if (name.includes('token_type')) inputValues = types
      const data = tokenTensorData(inputValues, inputs[i].dtype)
      if (data.byteLength !== inputs[i].dataSize) throw new Error('BGE token tensor size mismatch')
      inputs[i].setData(data)
    }
    const outputs = await this.model.predict(inputs)
    if (outputs.length === 0) throw new Error('BGE model returned no output')
    const raw = new Float32Array(outputs[0].getData())
    if (raw.length < EmbeddingModel.EMBEDDING_DIM) throw new Error('Unexpected BGE output dimension')
    const vector = new Array<number>(EmbeddingModel.EMBEDDING_DIM)
    let norm = 0
    for (let i = 0; i < EmbeddingModel.EMBEDDING_DIM; i++) norm += raw[i] * raw[i]
    norm = Math.sqrt(norm) || 1
    for (let i = 0; i < EmbeddingModel.EMBEDDING_DIM; i++) vector[i] = raw[i] / norm
    return vector
  }

  async encodeBatch(texts: string[]): Promise<number[][]> {
    const result: number[][] = []
    for (const text of texts) result.push(await this.encode(text))
    return result
  }

  isAvailable(): boolean { return this.loaded }
  getDimension(): number { return EmbeddingModel.EMBEDDING_DIM }

  private tokenize(text: string): number[] {
    const result = new Array<number>(EmbeddingModel.MAX_TOKENS).fill(this.padTokenId)
    result[0] = this.clsTokenId
    let position = 1
    const pieces: string[] = this.wordPieces(text.toLowerCase())
    for (const piece of pieces) {
      if (position >= EmbeddingModel.MAX_TOKENS - 1) break
      result[position++] = this.vocabulary[piece] ?? 100
    }
    result[position] = this.sepTokenId
    return result
  }

  private wordPieces(text: string): string[] {
    const basic = text.match(/[\u4e00-\u9fff]|[a-z0-9]+|[^\s]/g) ?? []
    const output: string[] = []
    for (const token of basic) {
      if (this.vocabulary[token] !== undefined) { output.push(token); continue }
      let start = 0
      let failed = false
      while (start < token.length) {
        let end = token.length
        let selected = ''
        while (start < end) {
          const value = (start === 0 ? '' : '##') + token.substring(start, end)
          if (this.vocabulary[value] !== undefined) { selected = value; break }
          end--
        }
        if (selected.length === 0) { failed = true; break }
        output.push(selected); start = end
      }
      if (failed) output.push('[UNK]')
    }
    return output
  }
}
