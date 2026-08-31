/**
 * Local BGE embedding adapter.
 *
 * Native MindSpore Lite wiring is intentionally exposed as an unavailable
 * capability until the matching NAPI runtime is packaged. Never return fake
 * vectors: callers must use their lexical fallback when this capability is off.
 */
export class EmbeddingModel {
  static readonly EMBEDDING_DIM: number = 512
  private loaded: boolean = false

  async loadModel(): Promise<void> {
    throw new Error('Local BGE model runtime is unavailable')
  }

  async encode(text: string): Promise<number[]> {
    if (!this.loaded) await this.loadModel()
    return []
  }

  async encodeBatch(texts: string[]): Promise<number[][]> {
    if (texts.length === 0) return []
    if (!this.loaded) await this.loadModel()
    return []
  }

  isAvailable(): boolean { return this.loaded }
  getDimension(): number { return EmbeddingModel.EMBEDDING_DIM }
}
