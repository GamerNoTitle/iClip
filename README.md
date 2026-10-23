# iClip 展示页

此分支为 **`gh-page`**，仅维护 iClip 的静态产品展示页。页面文件位于分支根目录，应用源码与构建脚本保留在 [`master`](https://github.com/GamerNoTitle/iClip/tree/master) 分支。

- 无构建步骤、无 npm 依赖、无外部字体或脚本请求。
- 直接打开 `index.html` 即可预览。
- 支持浅色 / 深色 / 跟随系统，以及剪贴板和 SwiftUI 风格设置表单的交互演示。

## 本地预览

```sh
git switch gh-page
python3 -m http.server 8787
# 打开 http://127.0.0.1:8787/
```

也可以直接运行 `open index.html`。

## GitHub Pages

将此分支推送到 GitHub 后，在仓库 **Settings → Pages → Build and deployment** 中选择：

- Source：Deploy from a branch
- Branch：`gh-page`
- Folder：`/ (root)`

根目录已包含 `.nojekyll`。使用 GitHub 默认域名时，发布地址为 `https://gamernotitle.github.io/iClip/`；是否实际可访问取决于 Pages 配置和部署结果。

## Vercel

将 Production Branch 设置为 `gh-page`：

- Root Directory：仓库根目录
- Framework Preset：Other
- Build Command：留空
- Output Directory：`.`

也可以在此分支根目录执行：

```sh
npx vercel --prod
```

`vercel.json` 提供 clean URL、基础安全头和静态资源缓存配置。

## Cloudflare Pages

将 Production Branch 设置为 `gh-page`：

- Root directory：仓库根目录
- Build command：留空
- Build output directory：`.`

也可以在此分支根目录执行：

```sh
npx wrangler pages deploy .
```

`_headers` 提供响应头配置，`wrangler.toml` 指定项目名和输出目录。无需 Pages Functions 或其他 serverless 运行时。

## 文件

- `index.html`：页面结构
- `styles.css`：设计系统与响应式样式
- `app.js`：演示交互、本地时钟、主题与截图预览
- `assets/`：应用图标与真实截图

真实截图来源于 `master` 分支的 `img/`。替换截图时，同步更新页面对应图片的尺寸。演示使用虚构数据，不读取用户的真实剪贴板，也不修改系统设置。
