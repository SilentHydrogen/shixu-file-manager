# Pi Agent on HarmonyOS

This package embeds the **unmodified official `@mariozechner/pi-agent-core` and `@mariozechner/pi-ai` 0.73.1** SDKs. `upstream-lock.json` pins their dependencies. SDK sources were downloaded and converted with Harmony's `ohpm convert`, and the resulting local SDK HAR is installed with `ohpm install` in `entry`.

`src/runtime.js` configures Pi's `Agent`, selects its official OpenAI Responses or Chat Completions provider, and registers the `classify_file` tool. The application callback goes through `FileClassificationStore.classify`. There is no application implementation of provider response JSON or SSE parsing. Application DTOs cross the ArkTS/JS boundary as JSON strings.

`src/platform.js` adapts Harmony HTTP to the SDK's Fetch interface, uses native text encoders/decoders and URL classes, and supplies standard Headers/Request/Response, Streams, AbortController and FormData polyfills. Native Harmony Blob supports FormData type checks. This application's inputs are text and extracted file excerpts. HTTP responses are buffered (8 MiB limit, 30 s connect / 60 s read timeout) and then consumed by **the SDK's SSE parser**; there is no token-by-token UI streaming yet. Both protocols require a provider supporting their standard streaming API.

The SDK's default provider barrel is narrowed to its own platform-neutral exports to exclude unrelated Node-only providers. No upstream provider or agent implementation is replaced. The bundle quotes `async return` method names and parenthesizes `yield` expressions for es2abc syntax compatibility. These are AST transformations, not protocol changes.

## Rebuild the vendored SDK

Use the project's CLT and a local esbuild installation:

```sh
export OHPM_PATH="$DEVECO_CLI_CLT_PATH/ohpm/bin/ohpm"
export ARKTS_TYPESCRIPT_PATH="$DEVECO_CLI_CLT_PATH/hvigor/hvigor-ohos-plugin/node_modules/typescript"
export ESBUILD_PATH=/absolute/path/to/esbuild
python3 scripts/vendor-pi-sdk.py
node packages/pi-agent-harmony/build.cjs
cd entry
"$OHPM_PATH" install ../packages/pi-agent-harmony/pi-agent-harmony.har --no-install_all
```

The restore script uses `ohpm convert` and verifies the converted runtime sources against pinned upstream tarballs. `ohpm` may report an unrelated transitive package conversion failure (the original all-provider dependency graph includes `@babel/runtime` without a `main` field); all actually bundled packages must be present and verified. The script restores npm **metadata** for export resolution; it does not use `npm install`.

The checked-in HAR is a vendored SDK dependency, not an app build output. Generated `index.js`, bundle metadata, `node_modules` and app artifacts are ignored. After changing the SDK HAR, run `devecocli build clean` before rebuilding: Hvigor's incremental dependency cache can otherwise reuse the old bytecode.

## Verification

```sh
node scripts/check-pi-sdk.cjs
```

This runs the real bundled SDK and real Harmony transport adapter with a fake native HTTP boundary, removing browser and Node globals before module initialization. Coverage includes Responses/Chat Completions SSE, Chinese text, tool execution and termination, invalid category rejection, HTTP 401 redaction and transport cleanup. It requires `ESBUILD_PATH`.

Upstream: https://github.com/badlogic/pi-mono/tree/781152fc24841dc54b22284514604048ebe5e2c9/packages/agent

Licenses: `THIRD_PARTY_LICENSES.txt` and `PI_LICENSE`.
