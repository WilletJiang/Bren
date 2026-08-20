# Bren JSONL Protocol v1

传输使用 stdin/stdout，每行恰好一个 JSON 对象。stdout 只承载协议，诊断日志写入 stderr。

## Request envelope

```json
{"v":1,"id":"request-1","method":"translate","params":{"text":"Hello."}}
```

字段：

- `v`: 当前固定为 `1`
- `id`: 客户端生成的非空请求 ID
- `method`: `translate`、`cancel` 或 `health`
- `params`: 方法参数

输入文本去除首尾空白后不能为空，最多 12,000 个 Unicode code point。

## Events

核心启动完成：

```json
{"v":1,"event":"ready","data":{"backend":"codex-app-server","model":"gpt-5.6-luna","version":"0.1.0"}}
```

翻译生命周期：

```json
{"v":1,"id":"request-1","event":"started","data":{"model":"gpt-5.6-luna"}}
{"v":1,"id":"request-1","event":"delta","data":{"text":"你"}}
{"v":1,"id":"request-1","event":"completed","data":{"text":"你好。","latencyMs":842}}
```

错误：

```json
{"v":1,"id":"request-1","event":"error","error":{"code":"timeout","message":"translation timed out","retryable":true}}
```

可能的终态是 `completed`、`cancelled` 或 `error`。

## Cancellation

```json
{"v":1,"id":"cancel-1","method":"cancel","params":{"requestId":"request-1"}}
```

开始新的翻译时，core 会自动取消所有仍在执行的旧翻译。显式 `cancel` 用于客户端关闭面板或未来的并行请求管理。

## Compatibility

新增可选字段保持向后兼容；改变字段含义或删除字段需要升级协议版本。平台客户端必须忽略未知 event 和未知 data 字段。
