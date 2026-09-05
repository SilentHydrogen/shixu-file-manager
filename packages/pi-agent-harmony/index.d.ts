export function runAgent(configJson: string, requestJson: string, runId: string,
  toolHandler?: (argumentsJson: string) => Promise<string>): Promise<string>;
export function cancelRun(runId: string): void;
