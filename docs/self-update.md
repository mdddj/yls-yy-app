# macOS 自更新接入说明

应用内已经接入 `Sparkle 2`，设置页里可以配置 `appcast.xml` 地址并手动检查更新。

要让更新真正可用，还需要补齐发布侧配置：

1. 生成 Sparkle EdDSA 密钥对。
   使用 Sparkle 自带的 `generate_keys`。
   把生成出来的公钥写入构建变量 `SPARKLE_PUBLIC_ED_KEY`。

2. 发布可下载的更新包。
   `GitHub Release` 可以存放 `.zip`、`.dmg` 或 `.pkg`，但它本身不提供 Sparkle 需要的 `appcast.xml`。

3. 生成 `appcast.xml`。
   使用 Sparkle 自带的 `generate_appcast`，对已经签名的发布包生成 appcast。

4. 托管 `appcast.xml`。
   推荐放到 `GitHub Pages` 或任意静态文件服务。
   应用里的“更新设置”填写的就是这个地址，例如：
   `https://<owner>.github.io/<repo>/appcast.xml`

5. CI/CD 需要确保这几个输入稳定存在。
   `SPARKLE_PUBLIC_ED_KEY`
   签名后的 macOS 发布包
   发布后的 `appcast.xml`

工程里已经预留了这两个构建变量：

- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_FEED_URL`

当前 `SPARKLE_PUBLIC_ED_KEY` 已经写入工程。
如果 `SPARKLE_FEED_URL` 为空，也可以在应用 UI 里单独配置更新源。

## GitHub 发布建议

- GitHub Actions 构建并签名 `.app`
- 打包为 Sparkle 支持的归档格式
- 运行 `generate_appcast`
- 上传归档到 Release
- 把 `appcast.xml` 和归档同步到 `gh-pages`

## 当前 UI 行为

- “检查更新”：调用 Sparkle 标准更新流程
- “更新设置”：配置 `appcast.xml`
- 如果缺少 `SPARKLE_PUBLIC_ED_KEY`，按钮会保持不可用，避免误触发失败弹窗
