# 写作与视觉风格规范（STYLE.md）

> 本文件是 `docs/source-analysis/` 系列的**唯一风格事实源**。所有写作 agent 落稿前必读，审校期按本文件逐条核对。基线 commit：`111030383`。

---

## 1. 行文约定

- **语言**：简体中文为主。**类名 / 方法名 / 包名 / SQL 关键字 / 设计模式名一律保留英文**，并用行内 code 包裹：`RelNode`、`SqlToRelConverter#convertQuery`、`GROUP BY`、`Flyweight`。
- **读者画像**：有数据库概念基础、能读 Java、第一次深读编译器/优化器源码的工程师。**不要从"什么是 SQL"讲起**；要把"这段代码为什么这么写、好在哪、可借鉴什么"讲透。
- **本系列的差异化视角**：是"**源码工程鉴赏**"，不是入门教程也不是查询流程叙事。每讲一个机制，落点必须回到三问之一：
  1. **软件工程**：关注点分离 / 不可变性 / 可测试性 / 可扩展性 / 复杂度治理。
  2. **数据工程**：pushdown / 类型系统 / 方言 / 联邦查询 / 代价模型。
  3. **设计与代码质量**：用了什么设计模式、为什么、防御式编程、有什么坑（pitfall）。
- **诚实**：探索结论里的 `pitfalls` 是**负面教训**，要如实写成"这里的权衡/代价/坑"，**不得**包装成优点。不确定的结论要么 Read 源码核实，要么不写。
- **篇幅**：每篇正文 400–800 行 markdown（含代码块与 SVG 引用）。

## 2. 每篇统一骨架（H2 级，缺一不可）

```
# 第 NN 篇 · <标题>

> 一句话导语（本篇回答什么工程问题、为什么值得读）。
> 基线 commit `111030383` · 前置阅读：第 X 篇

## TL;DR（3–6 条要点速览）
## 1. <正文小节…>            ← 含 SVG 引用与源码片段
## …
## 设计模式与工程小结        ← 本篇出现的模式/工程手法清单（表格）
## 对照阅读建议（动手）       ← 断点位置：file + Class#method + 观察什么（见 §6）
## 延伸阅读                  ← 交叉引用本系列其他篇 + 官方 site/_docs/ + 论文/JIRA
```

## 3. 源码引用格式（防腐烂是第一要务）

- **优先引用稳定锚点**：`类名 / 方法名 / 包路径`。行号会随主干提交漂移，**仅在确需精确定位时**才给行号。
- 路径用**仓库相对路径** + 行内 code：`` `core/src/main/java/org/apache/calcite/rex/RexBuilder.java` ``。
- 带行号时格式 `路径:行号` 或 `路径:起-止`，例如 `` `…/VolcanoPlanner.java:520-545` ``。
- **铁律**：任何带行号的引用，落稿前必须用 Read 工具打开该文件**实际确认**类/方法在该行附近。**禁止照搬 RESEARCH.md 里的行号**（那是探索期快照，可能已漂移）——RESEARCH.md 的行号只作"去哪个文件找"的线索。
- 代码片段：截取**最能说明设计意图的 5–25 行**，可省略无关行用 `// …` 标注；保留真实标识符。每段代码块前后用一句话点题。

## 4. SVG 设计系统

### 4.1 硬性兼容约束（GitHub / VS Code / IntelliJ 三处都要渲染）
1. 首行 `<?xml version="1.0" encoding="UTF-8"?>`；根 `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 W H" ...>`。
2. **根 `<svg>` 不写死 `width`/`height`**（靠 viewBox 自适应缩放）。
3. **绝对禁止 `<foreignObject>`**；所有文字用 `<text>` / `<tspan>`。多行文本用多个 `<text>` 或 `<tspan x=.. dy=..>` 手工换行（SVG 无自动折行）。
4. 第一个绘制元素是满画布白底：`<rect width="W" height="H" fill="#ffffff"/>`（暗色 IDE 主题下保证深色文字可读）。
5. 箭头/三角用 `<defs><marker></defs>` 定义，**不要用字符 `→` 画箭头**。
6. 特殊字符转义：`>`→`&gt;`、`<`→`&lt;`、`&`→`&amp;`（例：`Bindable&lt;Object[]&gt;`、`e.sal &gt; 1000`）。
7. 不引用外部字体 / 外部图片；纯矢量自包含。

### 4.2 画布尺寸（按图类型）
| 图类型 | viewBox（W×H） | 说明 |
|---|---|---|
| 架构图 / 全景分层 | `0 0 900 640`（最大 `1000 720`） | 横向分层，层间纵向箭头 |
| 类图 / 类继承图 | `0 0 920 660`（可加高到 760） | 分组栅格 + `«interface»`/`«abstract»` + 图例 |
| 流程图 | `0 0 960 600` ~ `960 720` | 单链横向；含分支时纵向 |
| 时序图 | `0 0 1000 820`（高度随消息数增长，步进 ≈36px/消息） | 列头 actor + 虚线生命线 + 激活条 |
| 对比矩阵 / 热力图 | `0 0 960 H`（行高 32、列宽 110–160） | 表头深色，单元格色块 |

### 4.3 语义配色（**固定，不随篇换色**）
| 角色 | 填充 | 描边 | 文字 |
|---|---|---|---|
| 模块 / 子系统容器 | `#DEEBF7`→`#BDD7EE`(linearGradient) | `#1F4E79` | `#1F4E79` |
| 接口 interface | `#E2EFDA` | `#548235` | `#385723` |
| 抽象类 abstract | `#FFF2CC` | `#BF8F00`(可虚边 `4,2`) | `#7F6000` |
| 具体类 / 普通节点 | `#FFFFFF` | `#1F4E79` | `#1a1a1a` |
| **高亮热点**（优化器/关键路径） | `#ED7D31` | `#7F3F00` | `#FFFFFF` |
| 正向调用/数据流 | — | `#1F4E79` 实线 | — |
| 返回/反向流 | — | `#548235` 虚线 `5,3` | `#385723` |
| 控制流/迭代框（loop/alt） | — | `#7030A0` 虚线 `6,3` | `#7030A0` |
| 弱引用/持有（非继承） | — | `#888` 虚线 `4,3` | `#888` |
| 外部系统/中性底 | `#F2F2F2` | `#595959` | `#262626` |
| 脚注 caption | — | — | `#A6A6A6` |

并列同类项（如多个 adapter 块）可用一组区分色，**仅表"并列"，不承载层级语义**。

### 4.4 字体
- 根字体族：`-apple-system, 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', Arial, sans-serif`
- 代码等宽族：`'SF Mono', Menlo, Consolas, monospace`
- 字号阶梯：标题 18–20(bold) / 副标题 12 / 分组标签 13(bold) / 类名 11(bold) / 方法签名 8.5–9(mono) / 普通标注 10–11 / 脚注 10。
- 中英混排：同一 `<text>` 内若需等宽代码，用 `<tspan font-family="'SF Mono',Menlo,monospace">` 局部切换。

### 4.5 marker 命名约定（全系列统一）
- `arrow`（实心正向，refX≈9）、`arrowBack`（绿色反向，refX≈1）、`inh`（空心三角=继承）、`ref`（细箭头=引用/持有）。
- 每张图在 `<defs>` 里定义自己用到的 marker（id 在单文件内唯一即可，沿用上述命名）。

### 4.6 图注与图例
- 每张图底部一行脚注：`图 篇号-序号 — 一句话说明`（如 `图 11-2 — …`）。颜色 `#A6A6A6`，10px。
- **类图必带图例块**（右下角）：至少含 interface / abstract / 具体类 / 继承 / 引用 五项。
- 用了多种线型的流程/时序图，须在脚注注明线色含义（参照 `docs/calcite-guide/svg/03-jdbc-sequence.svg` 脚注写法）。

### 4.7 参考样板（直接照着抄风格）
- 架构/分层：`docs/calcite-guide/svg/01-architecture.svg`
- 时序图：`docs/calcite-guide/svg/03-jdbc-sequence.svg`（生命线/激活条/返回虚线/loop 框/actor 列头）
- 类图（含图例、构造型）：`docs/calcite-guide/svg/04-relnode-tree.svg` 与 `07-convention-graph.svg`
- 流程：`docs/calcite-guide/svg/02-query-pipeline.svg`、`05-volcano-flow.svg`

## 5. 图片与交叉引用语法

- 正文引用 SVG（GitHub/IDE 通用）：`![图 NN-1：标题](../svg/NN-1-slug.svg)`（文章在 `articles/`，图在 `svg/`，故用 `../svg/`）。每张图正文必须有一段文字解读。
- 篇间引用：`[第 11 篇 · VolcanoPlanner](11-volcano.md)`（同目录相对链接）。
- 引用入门教材/第1卷作为延伸：用相对路径指向 `../../calcite-guide/README.md` 等。

## 6. "对照阅读建议"块写法（用户强需求）

每篇结尾给 2–4 个**可操作断点**，格式：
```
- **断点**：`core/src/.../SqlToRelConverter.java` → `SqlToRelConverter#convertQuery`
  - **观察**：`Blackboard.root` 如何从 null 逐步变为 LogicalProject；`subQueryList` 是否非空。
  - **运行**：`./gradlew :core:test --tests org.apache.calcite.test.SqlToRelConverterTest`（或对应 main()）。
```
优先引用记忆里已知的可运行入口：`core/src/test/java/org/apache/calcite/examples/RelBuilderExample.java`、`JdbcExample.java`、`example/csv` 的 `CsvTest`。

## 7. 防重复（single-owner 原则）

每个核心概念有唯一"主讲篇"（见 `BOUNDARIES.md` 的概念→篇映射）。非主讲篇引用该概念时**只能一句话带过 + 链接到主讲篇**，不得展开重讲。
