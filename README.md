# Hermes Dashboard 补丁项目

针对 [hermes-agent](https://github.com/NousResearch/hermes-agent) 网页端 dashboard（`web/`）的本地定制补丁集合。
所有改动都以前端源码补丁（git diff）形式存放，**不 fork 整个仓库**，对任意一份 hermes-agent 源码 checkout 都可以 `git apply` 后重新构建。

## 补丁列表

| 补丁文件 | 说明 | 基础版本 | 涉及文件 |
| --- | --- | --- | --- |
| `patches/plugins-page-ui.patch` | 插件管理页 UI 改造（累计补丁，含 Tab 化 + 卡片化 + 圆角）：①「已安装 / 插件目录 / 从 GitHub 安装」三个标签页，已安装默认置顶，GitHub 安装独立表单 +「固定提交」输入框（完整 commit SHA 钉版，走后端 install 接口现成的 `ref` 参数）；②插件列表从"一行一个"改为响应式卡片网格（1/2/3 列自适应），卡片显示名称、版本、来源、状态徽标与两行描述摘要，点「查看详情」弹窗展示完整信息并可执行启用/停用、更新、显隐、移除等操作；③页面组件（卡片、按钮、输入框、标签页、下拉、开关、详情弹窗）统一柔和圆角 | `b579fe6a938`（v0.23.4+585） | `web/src/pages/PluginsPage.tsx`、`web/src/lib/api.ts`、`web/src/i18n/{types,en,zh}.ts`、`web/src/index.css` |

### plugins-page-ui 效果

- 打开插件页默认显示**已安装**列表（原来是目录列表很长、已安装被挤到最底部）
- 标签页带数量角标（已安装 N / 目录 N）
- 「从 GitHub 安装」页：仓库填 `owner/repo`、`owner/repo/子目录` 或完整 `https://github.com/...` 地址；可选填完整 commit SHA 钉版
- 已安装 / 目录列表均为**卡片网格**（窄屏 1 列、中屏 2 列、宽屏 3 列），卡片只放摘要：名称、版本、来源、状态徽标、两行描述
- 卡片右下「查看详情」打开弹窗：完整描述、安装路径、slots、维护者/仓库/SHA、平台要求、认证命令，以及启用/停用、git 更新、侧边栏显隐、移除（带确认）
- 目录卡片能力标签（工具/钩子/中间件/环境变量）超出 3 个折叠为 `+N`，详情弹窗里看全量
- 页面所有组件柔和圆角：卡片 `rounded-2xl`、按钮/输入 `rounded-lg`、标签页 `rounded-xl`、状态徽标/开关 `rounded-full`；UI 库 Select 自身不暴露圆角参数，在 `index.css` 用 `[data-plugins-page] .plugins-select` 作用域规则补上
- 中英双语词条均已补齐（英文 fallback，无硬编码）

## 环境前提

- **Node.js ≥ 26**（hermes-agent 仓库 `engines` 硬性要求；Node 22 会报 `ERR_PNPM_UNSUPPORTED_ENGINE`）
  ```bash
  # 无管理员权限时可直接下载二进制到用户目录
  curl -sO https://nodejs.org/dist/v26.13.1/node-v26.13.1-linux-x64.tar.xz
  tar -xf node-v26.13.1-linux-x64.tar.xz
  export PATH=$PWD/node-v26.13.1-linux-x64/bin:$PATH
  ```
- **pnpm 12**（仓库根目录用 pnpm workspace）
- 一份 hermes-agent 源码（默认位置 `~/.hermes/hermes-agent`，`hermes` 安装包自带或手动 clone）

## 应用方法

### 方法一：一键脚本（推荐）

```bash
git clone https://github.com/MetaQian/hermes-dashboard-patches.git
./hermes-dashboard-patches/scripts/apply-and-build.sh plugins-page-ui.patch
```

脚本会自动：定位 hermes-agent 目录 → 校验 Node 版本 → `git apply` 补丁 → `pnpm install --frozen-lockfile` → `pnpm --dir web run build`。

可用环境变量覆盖默认值：

```bash
HERMES_DIR=/path/to/hermes-agent ./scripts/apply-and-build.sh plugins-page-ui.patch
```

### 方法二：手动四步

```bash
cd ~/.hermes/hermes-agent
git apply /path/to/patches/plugins-page-ui.patch   # 或 patch -p1 < 该文件
pnpm install --frozen-lockfile
pnpm --dir web run build
```

构建产物落在 `hermes_cli/web_dist/`，dashboard **按请求实时读取该目录，构建完成刷新浏览器页面即生效，无需重启 hermes 进程**（若 dist 目录缺失 dashboard 才会返回 404）。

### 回退补丁

```bash
cd ~/.hermes/hermes-agent
git apply -R /path/to/patches/plugins-page-ui.patch
pnpm --dir web run build
```

或 `./scripts/apply-and-build.sh --undo plugins-page-ui.patch`。

## ⚠️ hermes update 之后

`hermes update`（本质是 git pull）会**覆盖所有本地未提交改动**，补丁会失效。升级后重新应用即可：

```bash
./hermes-dashboard-patches/scripts/apply-and-build.sh plugins-page-ui.patch
```

若上游改了同一文件导致 `git apply` 冲突，可先试三路合并：

```bash
git apply --3way patches/plugins-page-ui.patch
```

仍冲突就人工解决（改动都集中在插件页：PluginsPage.tsx 的 Tab 条件渲染 + 卡片网格/详情弹窗、api.ts 的 `ref?: string` 字段、i18n 三个文件的可选词条、index.css 末尾一段 Select 圆角规则）。

## 补丁约定

- 只改 `web/` 前端，不动后端接口（用到的能力如 install 的 `ref` 参数都是上游现成的）
- i18n 新词条一律加为**可选 key**（`types.ts` 里 `?:`，调用处 `?? "英文fallback"`），不破坏其他语言文件
- 每个补丁独立成文件、可单独 apply/回退；新增补丁请补一行到上面的表格，并标注基础版本 commit