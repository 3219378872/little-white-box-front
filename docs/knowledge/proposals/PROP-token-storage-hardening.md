# PROP-0001 Web 端令牌存储加固（提案）

- id: PROP-token-storage-hardening
- status: draft
- owner: human
- created: 2026-08-23
- updated: 2026-08-23

## 背景与现状

当前会话令牌经 `sdk/vars/kv.dart` 以 JSON 明文存入 SharedPreferences；
Flutter Web 平台该插件落地为 `localStorage`，同源任意 XSS 可读取
accessToken / refreshToken。

已知事实：

- Flutter Web 上 `flutter_secure_storage` 底层同为 localStorage/IndexedDB，
  不提供真实加密，引入依赖无实质收益（2026-08 评审结论）。
- 传输层调试 print 泄漏已在 02365aa 移除；本提案只覆盖存储面。

## 已实施的缓解（2026-08-23）

根仓 `deploy/dev/proxy.conf` 对应用入口下发 CSP：

```
default-src 'self'; script-src 'self' 'wasm-unsafe-eval';
style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:
https://picsum.photos; font-src 'self' data:;
connect-src 'self' ws: wss:; worker-src 'self' blob
```

定位：XSS 升级屏障（限制外联与脚本注入面），不是加密替代。
`:3003` 直连开发服无反代、无 CSP，仅限本机。

## 待人类决策的候选方向

1. **维持现状 + CSP**（当前选择）：接受 localStorage 暴露，依赖 CSP 与
   后端短时 access token（30 分钟）+ refresh 轮换降低窗口。
2. **移动端 secure storage 分层**：为 Android/iOS 目标引入
   flutter_secure_storage 实现 kv 抽象的第二实现；Web 保持 localStorage。
3. **服务端会话缩减**：access token 改内存态不落存储，刷新走
   HttpOnly Cookie（需网关改造，跨端契约变更）。

## 影响

方向 2 需新增依赖（按仓库规则须人工批准）；方向 3 触及 `.api` 契约与
网关 CORS/cookie 语义。两者均超出本次修复范围，留待意图/规格层决策。
