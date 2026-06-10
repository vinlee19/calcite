# 各篇边界与概念归属（BOUNDARIES.md）— 防重复事实源

> 规则：每个核心概念有**唯一主讲篇**。非主讲篇引用它时**只能一句话 + 链接**，禁止展开重讲。落稿与审校都按本表执行。

## 概念 → 唯一主讲篇

| 概念 | 主讲篇 | 其他篇如何处理 |
|---|---|---|
| 五阶段流水线（总叙事） | 01 | 02 给四层 IR 视角；各篇只讲自己阶段 |
| 四层 IR / 分层降级 | 02 | 03–06、15 讲各自层，不重述"为什么分层" |
| SqlNode / SqlOperator / 三策略对象（算子侧） | 03 | 06 讲类型策略对象的实现细节，03 只讲算子如何持有 |
| 数据/行为分离 | 03 | 其他篇引用即链接 |
| RelNode 不可变 / copy() 契约 | 04 | 10/11/12 用到时一句话 |
| digest / RelDigest 去重 | 04 | 11 讲 memo 去重时链接到 04 |
| Shuttle / Visitor（三层各一套的对照） | 19 | 03(SqlVisitor)/04(RelShuttle)/05(RexShuttle)/15(tree.Shuttle) 各讲本层用法，"三层对照"归 19 |
| RexNode / RexProgram DAG / RexSimplify | 05 | 16 codegen 引用即链接 |
| 类型系统 Flyweight / TypeSystem 策略 / ReturnTypes 链 | 06 | 03 只一句话提"算子配三策略" |
| Flyweight / interning（模式总述） | 19 | 06(type)/14(traitSet) 各讲本处 interning 实现，模式归纳归 19 |
| Validator Scope/Namespace 双抽象 | 07 | — |
| SqlConformance 方言容差 | 07 | 09 一句话 |
| Blackboard / Convertlet 注册表 / 去关联 | 08 | — |
| Parser FMPP+JavaCC 代码生成 | 09 | 20 质量篇讲 buildSrc 构建插件时链接 09 |
| HepPlanner / HepProgram DSL | 10 | 11 对比时链接 |
| VolcanoPlanner / Memo(RelSet/RelSubset) / 双驱动 | 11 | 10 的"DAG vs Memo"图引出但不展开 Memo 内部 |
| RelRule.Config(Immutables) / Operand 匹配树 / CoreRules | 12 | 11 只讲 driver 如何调度规则；Immutables 模式总述归 19 |
| RelMetadataQuery / Janino provider / 循环防护 | 13 | 11 代价驱动一句话链接 |
| RelOptCost / VolcanoCost | 13 | 11 用到即链接 |
| Trait/Convention / interning / 传播 / Convention 网络 | 14 | 17/18 讲 adapter Convention 时链接 14 |
| 联邦查询（federation）本质 | 14 | 17 给 SPI 视角，18 给具体 adapter 案例 |
| linq4j Enumerable/Enumerator / Expression Tree / BlockBuilder CSE | 15 | 16 codegen 引用即链接 |
| Enumerable codegen / Janino 编译 / PhysType / Interpreter | 16 | — |
| RexToLixTranslator / NullPolicy | 16 | 05 不讲翻译，只讲 RexNode 本体 |
| Schema/Table SPI 能力分层 / Wrapper | 17 | 18 直接用，不重述接口定义 |
| 5 adapter 对比 / RelToSql / SqlDialect / pushdown 矩阵 | 18 | 14 讲 trait 时不举 adapter 完整案例 |
| 设计模式总览（Builder/Factory/Strategy/Registry/Template/Visitor/Flyweight/Immutables） | 19 | 各机制细节在其主讲篇，19 只做"模式视角"归纳 + 指针 |
| RelBuilder | 19 | 其他篇用到即链接 |
| 构建/静态检查（werror/Checker/ErrorProne/forbiddenapis/RAT）、测试体系、util 精品、Hook、全模块巡礼 | 20 | 09 讲 Parser 构建是 build 子集，链接 20 看全局 |
| 子查询特性全链路 / `RexSubQuery` / `SubQueryRemoveRule`（特性视角） | 21 | 08 仍主讲去关联机制本体；12 主讲规则机制；21 只讲"特性如何流过五阶段" |
| CTE 特性全链路 / `SqlWith` / 内联展开 vs `RepeatUnion` / `Spool`+`TransientTable` | 21 | 07 讲 WithScope 作用域本体；21 讲 convertWith/内联与递归改写 |
| 开窗特性全链路 / `RexOver` / `Window.Group` / `ProjectToWindowRule` / `EnumerableWindow` | 21 | 07 讲窗口校验本体；12 主讲规则机制；16 主讲 codegen；21 串特性全链路 |

## 每篇"不讲什么"速查（转引目标见上表）

- 01：不讲任何阶段算法。
- 02：不讲单层细节、不讲优化。
- 03：不讲校验/转 Rel/类型策略实现。
- 04：不讲 digest 在优化器的用法、不讲 codegen。
- 05：不讲表达式 codegen 翻译。
- 06：不讲算子注册流程。
- 07：不讲解析、不讲类型策略本体。
- 08：不讲优化器。
- 09：不讲 validator、不讲全局构建体系（→20）。
- 10：不讲 Volcano memo 内部。
- 11：不讲规则类设计、不讲 trait 内部、不讲元数据实现。
- 12：不讲 driver 调度细节、不讲 Immutables 模式归纳（→19）。
- 13：不讲主循环。
- 14：不讲完整 adapter 案例。
- 15：不讲算子级 codegen。
- 16：不讲 Expression tree 本体（→15）、不讲 RexNode 本体（→05）。
- 17：不讲具体 adapter 差异（→18）。
- 18：不讲 SPI 接口定义（→17）。
- 19：不讲每个模式的机制细节（链接到主讲篇）。
- 20：不讲 Parser 模板语法细节（→09）。
- 21：不讲去关联机制本体（→08）、不讲 Scope/Namespace 本体（→07）、不讲规则匹配机制（→12）、不讲 codegen/执行引擎本体（→16）、不讲四层 IR 为何分层（→02）；只讲三特性各自专属的 IR 节点与"转换/消解"那一步如何流过五阶段。
