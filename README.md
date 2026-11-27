# Hermes Dashboard 补丁项目

针对 [hermes-agent](https://github.com/NousResearch/hermes-agent) 网页端 dashboard（`web/`）的本地定制补丁集合。
所有改动都以前端源码补丁（git diff）形式存放，**不 fork 整个仓库**，对任意一份 hermes-agent 源码 checkout 都可以 `git apply` 后重新构建。

## 补丁列表

| 补丁文件 | 说明 | 基础版本 | 涉及文件 |
| --- | --- | --- | --- |
| `patches/plugins-page-ui.patch` | dashboard 前端累计定制补丁（每次改动整体重新导出，`git apply --check -R` 校验过），当前含七块：①插件管理页 UI 改造（Tab 化 + 卡片网格 +「固定提交」钉版 + 详情弹窗）；②多页面中文化（定时任务 / MCP / Webhooks / 频道 / 技能 / 会话页，可选 i18n key + `?? "英文fallback"`，共享 `uiKit.ts` 的 `BADGE_CN` 徽标样式）；③会话列表修剪（`session-prune.ts`）；④**全站圆角**（见下节）；⑤导航栏汉化（文件 / 频道 / Webhooks / 配对 / 系统 5 项 + 页面标题同步）；⑥**系统区移到顶部 banner 右侧**（见下节）；⑦代码 chip 去底色（MCP 页 + OAuth 提供商卡片） | `b579fe6a938`（v0.23.4+585） | `web/src/App.tsx`、`web/src/index.css`、`web/src/components/OAuthProvidersCard.tsx`、`web/src/contexts/PageHeaderProvider.tsx`、`web/src/i18n/{types,en,zh}.ts`、`web/src/lib/{api,session-prune,resolve-page-title}.ts`、`web/src/pages/{PluginsPage,PluginsPage_updateAll,AnalyticsPage,ChannelsPage,ChatPage,ConfigPage,CronPage,EnvPage,McpPage,ModelsPage,ProfileBuilderPage,SessionsPage,SkillsPage,WebhooksPage,uiKit}.tsx`（共 25 个文件） |

### plugins-page-ui 效果

- 打开插件页默认显示**已安装**列表（原来是目录列表很长、已安装被挤到最底部）
- 标签页带数量角标（已安装 N / 目录 N）
- 「从 GitHub 安装」页：仓库填 `owner/repo`、`owner/repo/子目录` 或完整 `https://github.com/...` 地址；可选填完整 commit SHA 钉版
- 已安装 / 目录列表均为**卡片网格**（窄屏 1 列、中屏 2 列、宽屏 3 列），卡片只放摘要：名称、版本、来源、状态徽标、两行描述
- 卡片右下「查看详情」打开弹窗：完整描述、安装路径、slots、维护者/仓库/SHA、平台要求、认证命令，以及启用/停用、git 更新、侧边栏显隐、移除（带确认）
- 目录卡片能力标签（工具/钩子/中间件/环境变量）超出 3 个折叠为 `+N`，详情弹窗里看全量
- 页面所有组件柔和圆角：卡片 `rounded-2xl`、按钮/输入 `rounded-lg`、标签页 `rounded-xl`、状态徽标/开关 `rounded-full`；UI 库 Select 自身不暴露圆角参数，在 `index.css` 用 `[data-plugins-page] .plugins-select` 作用域规则补上
- 中英双语词条均已补齐（英文 fallback，无硬编码）

### 全站圆角（所有页面）

UI 库（`@nous-research/ui`）的 Card / Button / Input / Dialog / Switch 等组件**默认全部直角**，不读取主题圆角变量。插件页是圆角参考页（JSX 里逐处加了 `rounded-*`），其余页面靠 `index.css` 末尾一段**无层级（unlayered）CSS 规则**统一补齐——无层级规则在级联上压过 Tailwind 的 `@layer utilities` 和 UI 库硬编码类，一处生效全站：

| 选择器 | 圆角 | 覆盖对象 |
| --- | --- | --- |
| `div.border-midground\/15.bg-background-base\/80` | 16px（rounded-2xl） | 所有 `<Card>`（该组合类全库只有 Card 原语带） |
| `[data-slot='dialog-content']` | 16px | 所有弹窗（含各组件里的 Confirm/Picker 弹窗） |
| `button` | 8px（rounded-lg） | 所有按钮；Switch 有更具体的规则保持 8px 轨道 |
| `input`/`textarea`（排除 checkbox/radio） | 8px | 所有表单控件 |
| `button[role='combobox']`、`[role='listbox']` | 8px | Select 触发器 + 下拉面板（插件页保留自己的 10px 作用域规则） |
| `code`、`pre` | 8px | 代码 chip 与代码块 |
| `span.font-compressed` | 9999px（胶囊） | 状态徽标（该压缩字体带边框的只有 Badge） |

各页面里**非 Card 的卡片式 div**（列表行、统计条、错误条、QR 框、图表 tooltip、聊天气泡等）无法用统一选择器命中，已在 JSX 里逐处加了 `rounded-2xl`（面板/容器）、`rounded-xl`（列表行）、`rounded-lg`（错误/警告条、下拉、tooltip），涉及 11 个页面文件。

注意：这套规则依赖 Tailwind v4（utilities 在 `@layer` 里）+ UI 库的硬编码类名。上游若改了 Card 的类组合或 `data-slot`，需重新核对选择器。

另外：DS 的 `globals.css` 会给**所有** `code` 元素加"选区高亮"底色（`*::selection, code { background: var(--selection-bg, …) }`，无层级，utility 类盖不住）。MCP 页卡片的端点 URL、OAuth 提供商卡片的登录命令（cli_command）因此带底色，已分别用 `[data-mcp-page] code` 和 `[data-oauth-card] code` 作用域到两个页面/卡片根节点（`data-mcp-page`、`data-oauth-card` 属性）覆盖为透明底；其余页面保留 chip 观感，要全站去掉就改成全局 `code` 规则。

### 系统区移到顶部 banner 右侧

原来左侧导航栏下半部有一整块系统区（「系统」标题、网关状态 + 活跃会话数、重启网关 / 更新 Hermes 按钮、折叠态的网关小圆点）。现在整块移到了**每个页面顶部 banner 的最右侧**（`GatewayBannerActions`，挂在 `PageHeaderProvider` 新增的 `actions` prop 上，全路由通用）：

- 状态胶囊：网关状态圆点（绿/黄/红）+「系统 运行中 · 活跃会话：N」，点击跳 /sessions；窄屏只留圆点
- 重启网关 / 更新 Hermes 图标按钮（更新项仍只在 `can_update_hermes` 时出现），运行中显示转圈，确认弹窗逻辑与原侧边栏完全一致
- 主题切换按钮原样搬入（显示当前主题名，下拉向下展开）
- 侧边栏相应删掉了该区块和主题切换（语言切换、版本页脚保留在左侧）
- 上游若新增/改名 banner（`role="banner"`）结构，需重新核对 `PageHeaderProvider` 的 `actions` 插槽位置

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

仍冲突就人工解决（改动集中在：PluginsPage.tsx 的 Tab 条件渲染 + 卡片网格/详情弹窗、api.ts 的 `ref?: string` 字段、i18n 三个文件的可选词条、index.css 末尾的 UI 库覆盖规则（Select/开关/Label/全站圆角）、以及各页面的中文化词条与卡片式 div 的 `rounded-*` 类）。

## 补丁约定

- 只改 `web/` 前端，不动后端接口（用到的能力如 install 的 `ref` 参数都是上游现成的）
- i18n 新词条一律加为**可选 key**（`types.ts` 里 `?:`，调用处 `?? "英文fallback"`），不破坏其他语言文件
- 每个补丁独立成文件、可单独 apply/回退；新增补丁请补一行到上面的表格，并标注基础版本 commit