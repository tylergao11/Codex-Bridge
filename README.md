# Codex-Bridge

让 Codex Desktop/CLI 使用 DeepSeek V4 Pro。

## 解决的问题

**1. DeepSeek 与 Codex 协议原生不适配**

**2. Codex 原生 tool-search（GPT-5.4+）在 DeepSeek 上不可用**

**3. 针对 DeepSeek KV 缓存的深度优化**

**4. Codex 原生对中文的崩溃、乱码、转义不支持**

**5. 拟态运行，大幅提升流畅度**

---

## 快速开始

```powershell
.\scripts\install.ps1 -ApiKey "你的DeepSeek-API-Key"
```

配完重启 Codex 即可。

## 日常命令

```powershell
.\scripts\status.ps1    # 查看 bridge 状态
.\scripts\stop.ps1      # 停止 bridge
.\scripts\start.ps1     # 启动 bridge
.\scripts\verify.ps1    # 验证 bridge 是否正常
```

### 换 API Key

```powershell
.\scripts\one-key-api-key.ps1 -ApiKey "新的Key"
```

### 还原到 ChatGPT

```powershell
.\scripts\restore.ps1
```
