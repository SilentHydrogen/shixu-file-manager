<!-- managed-by: pi-workflow -->
# Project Workflow Context

## Request

/tmp/handoff-shixu-file-manager.md,请你根据这个handoff工作报告，修复鸿蒙手机实机测试时，基于llm的RAG文件整理服务没有ui界面，无法使用llm的任何整理服务，请你修复，可以使用devecocli工具，我的手机全程连接在电脑上

## Repository

- Project: `tmp-handoff-shixu-file-manager-md-请你根据这个handoff工`
- Root: `/home/cmz488/Projects/cpp_file/shixu-file-manager/worktree/tmp-handoff-shixu-file-manager-md-请你根据这个handoff工`
- Branch: `workflow/tmp-handoff-shixu-file-manager-md-请你根据这个handoff工`
- HEAD: `0b332ec4fe4c7b776fb7548ff43a6c3dd54b395e`
- Context hash: `sha256:e87e8c270ea2084fca7bc111e6d5d7d12f9ba811aeda1d3d47fe487faa02b0ba`

## Structure

- `.gitignore`
- `.pi/`
- `AGNETS.md`
- `AppScope/`
- `DEVELOPMENT_PROGRESS.md`
- `LLM_INTEGRATION.md`
- `QUICKSTART.md`
- `README.md`
- `SUMMARY.md`
- `action-sheet.jpeg`
- `animation-check.jpeg`
- `box-screen.jpeg`
- `build-profile.json5`
- `code-linter.json5`
- `commit_llm_integration.sh`
- `current.jpeg`
- `docs/`
- `entry/`
- `hvigor/`
- `hvigorfile.ts`
- `mise.toml`
- `oh-package-lock.json5`
- `oh-package.json5`
- `test-fixtures/`
- `widget-glass-2.jpeg`
- `widget-glass.jpeg`
- `workflow.md`

## Manifests And Constraints

- `mise.toml`: `sha256:aec45050717409834b1771b9926feff8c35813c449bed30b761f8918f820f16b`
- `README.md`: `sha256:d6eb789e893bd85f9be2bf23e2c8983ab3ce93b018dd0546b34f59893a5bd4db`

## Workflow

- Status: `IMPLEMENTING_STAGE`
- Contract: `sha256:43ecd14e49778882a777b7659e48b70e61dd3db415fcd7cc26c608b9fdbaa538`
- Current stage: `implement-and-verify - 按 TDD 顺序补测试替身与失败测试，修复 UI/数据/LLM/RAG/本地模型/目录调度，再执行 lint、构建、Git LFS 和连接手机端到端验收；缺少 MindSpore Lite 运行时只阻塞本地向量验收，不阻塞 LLM 降级主流程。`

## Agent Context

模型工件已核对：`entry/src/main/resources/rawfile/models/bge-small-zh-v1.5-int8.ms`、`tokenizer.json`、`config.json` 三者均存在，均为未跟踪本地工件；`MODEL_PORTING_REPORT.md` 记录 BGE-Small-ZH v1.5 INT8、512 维、输入 `int64[1,512]`、输出 `fp32[1,512,512]`、CLS pooling、L2 归一化，转换运行时为 MindSpore Lite 2.3.0。代码仍是 384 维随机占位；真实接入方案已选 C++ NAPI + ArkTS wrapper。

### Relevant Paths

- `MODEL_PORTING_REPORT.md`
- `entry/src/main/resources/rawfile/models/bge-small-zh-v1.5-int8.ms`
- `entry/src/main/resources/rawfile/models/tokenizer.json`
- `entry/src/main/resources/rawfile/models/config.json`
- `entry/src/main/ets/ai/model/EmbeddingModel.ets`
- `entry/src/main/ets/data/database/DatabaseConfig.ets`
- `entry/src/main/cpp/CMakeLists.txt`
- `entry/src/main/cpp/napi_init.cpp`
- `entry/src/main/ets/llm/LLMService.ets`
- `entry/src/main/ets/service/RagAnalysisService.ets`
- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/pages/ChatPage.ets`
- `entry/src/main/ets/pages/LLMConfigPage.ets`
- `entry/src/main/ets/components/ChatInterface.ets`

### Commands

- `DEVECO_CLI_CLT_PATH=/home/cmz488/Downloads/commandline-tools-linux-x64-26.0.0.821/command-line-tools DEVECO_SDK_HOME=$DEVECO_CLI_CLT_PATH/sdk CI=true devecocli check lint .`
- `DEVECO_CLI_CLT_PATH=/home/cmz488/Downloads/commandline-tools-linux-x64-26.0.0.821/command-line-tools DEVECO_SDK_HOME=$DEVECO_CLI_CLT_PATH/sdk CI=true devecocli build`
- `DEVECO_CLI_CLT_PATH=/home/cmz488/Downloads/commandline-tools-linux-x64-26.0.0.821/command-line-tools devecocli run --module entry --device <serial>`
- `DEVECO_CLI_CLT_PATH=/home/cmz488/Downloads/commandline-tools-linux-x64-26.0.0.821/command-line-tools devecocli ui layout --device <serial> --format json --mode full`
- `DEVECO_CLI_CLT_PATH=/home/cmz488/Downloads/commandline-tools-linux-x64-26.0.0.821/command-line-tools devecocli ui screenshot --device <serial> --path ./artifacts/device.png`
