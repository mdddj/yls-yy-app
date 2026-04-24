# GitHub Release / Sparkle 配置

这个项目已经接入了 Sparkle，应用内可以检查更新，但真正生效还需要仓库侧完成两个条件：

1. 发布 `zip` 更新包
2. 发布 `appcast.xml`

当前仓库已经补了 workflow：

- `.github/workflows/release-macos.yml`

它会在推送 `v*` 标签时：

1. 构建 macOS Release 包
2. 生成 `yls-app-<version>.zip`
3. 上传到 GitHub Release
4. 生成 `appcast.xml`
5. 部署 `appcast.xml` 到 GitHub Pages

## 你缺少的“公钥”是什么

这是 Sparkle 的更新签名公钥。

- `公钥`：放进应用里，用户机器用它验证更新包和 appcast 没被篡改
- `私钥`：只放在你自己机器或 CI Secret 里，用它给更新签名

这两个是一对。没有公钥，应用就没法安全验证更新，所以我在 UI 里把“检查更新”按钮默认做成了不可用。

## 怎么生成

先确保本地已经解析过 Sparkle 包。你现在已经构建过一次了，所以可以直接用本地工具。

先找工具：

```bash
find ~/Library/Developer/Xcode/DerivedData -path '*Sparkle/bin/generate_keys' | head -n 1
```

假设输出是：

```bash
~/Library/Developer/Xcode/DerivedData/.../Sparkle/bin/generate_keys
```

然后执行：

```bash
"$GENERATE_KEYS" --account yls-yy-app
```

它会：

- 如果没有密钥，就生成一对
- 如果已经有密钥，就复用
- 把私钥保存进你的 Keychain
- 把公钥打印到终端

只读取公钥：

```bash
"$GENERATE_KEYS" --account yls-yy-app -p
```

导出私钥到文件：

```bash
"$GENERATE_KEYS" --account yls-yy-app -x /tmp/yls-yy-app-sparkle-private-key.txt
```

## GitHub Secrets 要配什么

仓库 `Settings > Secrets and variables > Actions` 里至少加这两个：

- `SPARKLE_PUBLIC_ED_KEY`
  值就是 `generate_keys` 打印出来的公钥字符串
- `SPARKLE_PRIVATE_KEY`
  值就是你导出的私钥文件内容

说明：

- `SPARKLE_PUBLIC_ED_KEY` 不敏感，但放 secret 里管理最省事
- `SPARKLE_PRIVATE_KEY` 是敏感信息，绝对不要进仓库

## 首次启用 Pages

1. 打开仓库 `Settings > Pages`
2. Source 选择 `GitHub Actions`

之后 workflow 会自动把 `appcast.xml` 部署到：

```text
https://mdddj.github.io/yls-yy-app/appcast.xml
```

## 发布方式

发布一个新版本时：

```bash
git tag v1.0.0
git push origin v1.0.0
```

workflow 会自动：

- 构建应用
- 上传 Release 资产
- 更新 Pages 上的 `appcast.xml`

## 当前限制

当前 workflow 走的是最短路径，已经足够把 Sparkle 更新链路打通。

还没做的两件事：

- Developer ID 签名
- Apple notarization

如果你要把这个 app 发给别人长期使用，下一步应该补这两个。否则下载和更新虽然能跑，但会遇到 Gatekeeper 的体验问题。
