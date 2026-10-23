# iClip 展示页

`site/` 是一个**纯静态**的产品展示页，用来展示 iClip 的剪贴板面板、交互方式、设置界面和隐私设计。

- 无构建步骤、无 npm 依赖、无外部字体或脚本请求。
- 直接双击 `index.html` 就能离线打开。
- 浅色 / 深色 / 跟随系统三种外观，选择会保存在本地。
- 剪贴板演示支持搜索、<kbd>↑</kbd> <kbd>↓</kbd> 选择、<kbd>↵</kbd> 粘贴、置顶和删除。
- 设置表单复刻 SwiftUI 的 `Form` / `Toggle` / `Picker` / `Stepper`，并配有一份带语法高亮的 `SettingsView.swift`。

## 本地预览

```sh
cd site
python3 -m http.server 8787
# 打开 http://127.0.0.1:8787/
```

也可以直接打开文件，不需要服务器：

```sh
open site/index.html
```

## 部署

页面没有后端依赖，Vercel 和 Cloudflare Pages 都可以直接托管。`site/` 里的配置是可选的便利项，不会影响本地打开。

### Vercel

在 Vercel 新建项目后：

- Root Directory：`site`
- Framework Preset：Other
- Build Command：留空
- Output Directory：`.`（即 `site/`）

或使用 CLI：

```sh
cd site
npx vercel --prod
```

`vercel.json` 会启用 clean URL、基础安全头和静态资源长缓存。

### Cloudflare Pages

在 Cloudflare Pages 连接仓库后：

- Build command：留空
- Build output directory：`site`

或使用 Wrangler：

```sh
cd site
npx wrangler pages deploy .
```

`_headers` 会启用基础安全头和静态资源缓存；`wrangler.toml` 只用于指定项目名和输出目录，可按需改名。页面没有 Pages Functions，不需要 serverless 运行时。

## 结构

```
site/
├── index.html          # 页面结构
├── styles.css          # 设计系统和响应式样式
├── app.js              # 面板演示、主题、截图切换、lightbox
├── assets/             # 应用图标、菜单栏图标、真实截图
├── vercel.json         # Vercel 静态配置
├── _headers            # Cloudflare Pages 响应头
└── wrangler.toml       # Cloudflare Pages 项目配置
```

## 更新截图

页面里的真实界面图来自仓库的 `img/`。替换 `assets/settings-light.png` 或 `assets/panel-light.png` 后，如果尺寸变化，请同步更新 `index.html` 里对应 `<img>` 的 `width` / `height`。设置截图当前裁掉了透明外边距（893 × 994），这样在展示卡里更大、更清晰。

## 说明

- 所有截图和图标都来自本仓库；页面不抓取真实剪贴板内容。
- 演示数据是虚构的；交互只在浏览器里发生。
- 页面不会发起网络请求，外链只会在用户点击时打开 GitHub。
