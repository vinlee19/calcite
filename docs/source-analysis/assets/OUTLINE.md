# 全系列大纲（OUTLINE.md）— 唯一事实源

> 20 篇 + README，约 50 张 SVG。每篇 SVG 文件名规范：`svg/NN-序号-slug.svg`（如 `svg/11-2-memo-arch.svg`）。
> 每篇正文文件名：`articles/NN-slug.md`。基线 commit `111030383`。

图例：★ = IR 重心篇；【类型】Arch=架构图 / Class=类图 / Flow=流程图 / Seq=时序图 / Matrix=对比矩阵。

---

## 00 · README.md — 系列索引 / 阅读路线 / 设计哲学
- 目标：用一页讲清"这套文档是什么视角、怎么读、和 calcite-guide/第1卷的分工"。
- SVG：`svg/00-1-reading-map.svg`【Arch/Flow】阅读路线图（按主题分组 + 推荐顺序 + 依赖箭头）。
- 内容：系列定位（源码工程鉴赏）；20 篇目录表（链接）；4 条阅读路线（IR 路线/优化器路线/数据工程路线/质量路线）；交叉引用既有资产；基线 commit 声明。

## 01 · 01-positioning.md — 工程定位与"无存储"架构哲学
- 目标：从软件工程角度解释"前端公共化、后端专业化"的关注点分离为何成就 Calcite。
- 锚点：`org/apache/calcite/package-info.java`、`schema/ScannableTable`、`settings.gradle.kts`、`plan/Convention`。
- SVG：
  - `svg/01-1-landscape.svg`【Arch】Calcite 整体分层全景（Clients→Core 五阶段→linq4j→Adapters）。
  - `svg/01-2-module-topology.svg`【Arch】模块依赖拓扑（core 为心、linq4j 底座、adapter-* 外围）。
- 边界：不展开任何阶段算法（→各篇）。

## 02 · 02-ir-overview.md — 为什么是四层 IR ★
- 目标：把 SqlNode→RelNode→RexNode→Expression 的"四层降级"讲成一个连贯的工程决策，解释分层的收益与代价。
- 锚点：`sql/SqlNode`、`rel/RelNode`、`rex/RexNode`、`linq4j/tree/Expression`；通用 Visitor/Shuttle 范式。
- SVG：
  - `svg/02-1-four-ir-lowering.svg`【Flow】四层 IR 降级流水线（每层职责 + 转换器 + 不可变标注）。
  - `svg/02-2-ir-boundaries.svg`【Arch】层间转换边界（谁把 A 转成 B：parse/validate/sql2rel/RexToLix）。
- 边界：每层细节交给 03–06、15；不讲优化（→10–14）。

## 03 · 03-sqlnode.md — SqlNode AST：数据/行为分离 ★
- 锚点：`sql/SqlNode`、`SqlCall`、`SqlOperator`（returnType/operandType/operandChecker 三策略）、`SqlKind`、`SqlParserPos`、`SqlDialect.unparseCall`、`SqlVisitor`/`SqlBasicVisitor`。
- SVG：
  - `svg/03-1-sqlnode-class.svg`【Class】SqlNode 子类树 + SqlOperator 组合 + 三策略对象。
  - `svg/03-2-unparse-dialect.svg`【Flow】unparse + 优先级括号 + 方言定制。
  - `svg/03-3-visitor-dispatch.svg`【Seq】accept→visit double-dispatch。
- 边界：不讲校验（→07）、不讲转 Rel（→08）。

## 04 · 04-relnode.md — RelNode 关系代数层 ★
- 锚点：`rel/AbstractRelNode`（digest/rowType 缓存/id）、`RelNode#copy`、`rel/core/{Project,Filter,Join,Aggregate}`、`rel/logical/*`、`RelShuttle`/`RelShuttleImpl`/`RelHomogeneousShuttle`、`RelWriter`/`externalize/RelJsonWriter`。
- SVG：
  - `svg/04-1-relnode-class.svg`【Class】AbstractRelNode→SingleRel/BiRel + 各算子 + Logical/Physical 双层。
  - `svg/04-2-immutable-copy.svg`【Flow】copy() 不可变变换序列（原节点保留）。
  - `svg/04-3-shuttle-traverse.svg`【Flow/Seq】RelShuttle 遍历改写链。
- 边界：digest 在优化器中的用途只一句话（→11）。

## 05 · 05-rexnode.md — RexNode 行表达式与 RexProgram DAG ★
- 锚点：`rex/RexNode`、`RexBuilder`（常量缓存/makeCall 规范化）、`RexCall`、`RexInputRef`、`RexLocalRef`、`RexProgram`/`RexProgramBuilder`（DAG 共享）、`RexSimplify`、`RexShuttle`。
- SVG：
  - `svg/05-1-rexnode-class.svg`【Class】RexNode 子类 + operands 结构。
  - `svg/05-2-rexprogram-dag.svg`【Arch】RexProgram 的 exprs/projects/condition 通过 RexLocalRef 共享 DAG（对比展开式）。
  - `svg/05-3-simplify-pipeline.svg`【Flow】RexSimplify 化简流水线（折叠/谓词/强度 + RexUnknownAs）。
- 边界：codegen 翻译（→16）。

## 06 · 06-type-system.md — 类型系统：Flyweight + 策略 ★
- 锚点：`rel/type/RelDataType(Factory)`、`RelDataTypeFactoryImpl`（KEY2TYPE_CACHE/DATATYPE_CACHE/Interner）、`RelDataTypeSystem(Impl)`、`sql/type/{ReturnTypes,OperandTypes,InferTypes}`（chain/cascade）。
- SVG：
  - `svg/06-1-factory-cache.svg`【Arch】Factory 二级缓存 / interning。
  - `svg/06-2-three-strategies.svg`【Class】SqlOperator 的三策略对象依赖。
  - `svg/06-3-infer-chain.svg`【Flow】ReturnTypes.chain/cascade 推导链。
- 边界：算子注册（→03）。

## 07 · 07-validator.md — Validator：Scope/Namespace 双抽象
- 锚点：`sql/validate/SqlValidatorImpl`（deriveType）、`SqlValidatorScope.resolve` vs `SqlValidatorNamespace.getRowType`、`SelectScope`/`ListScope`/`DelegatingScope`/`GroupByScope`/`JoinScope`、`SelectNamespace`/`IdentifierNamespace`、`SqlConformance`。
- SVG：
  - `svg/07-1-scope-namespace-class.svg`【Class】Scope 与 Namespace 两条继承树并置。
  - `svg/07-2-validate-seq.svg`【Seq】validateSelect → resolve 链式查找。
- 边界：解析（→09）、类型推导策略本体（→06）。

## 08 · 08-sql-to-rel.md — SqlToRel：Blackboard + Convertlet
- 锚点：`sql2rel/SqlToRelConverter`（convertQuery）、内部 `Blackboard`、`StandardConvertletTable`/`ReflectiveConvertletTable`、`RelDecorrelator`、`AggConverter`。
- SVG：
  - `svg/08-1-blackboard-arch.svg`【Arch】convertQuery 调用栈 + Blackboard 共享状态。
  - `svg/08-2-convertlet-lookup.svg`【Flow】Convertlet 分层查找（instance→class→expr）。
  - `svg/08-3-decorrelate.svg`【Flow】子查询去关联（RexSubQuery→Correlate）。
- 边界：算子如何被优化（→10–14）。

## 09 · 09-parser-codegen.md — Parser 代码生成工程（FMPP+JavaCC）
- 锚点：`core/src/main/codegen/{config.fmpp,default_config.fmpp,templates/Parser.jj}`、`buildSrc/subprojects/{fmpp,javacc}`、`sql/parser/{SqlParser,SqlAbstractParserImpl}`、`babel`/`server` 的 `config.fmpp`。
- SVG：
  - `svg/09-1-codegen-build.svg`【Flow】config.fmpp + Parser.jj → FMPP → JavaCC → SqlParserImpl。
  - `svg/09-2-core-vs-babel.svg`【Matrix/Arch】Core vs Babel 配置差异（关键字/算子/解析方法）。
- 边界：validator（→07）。

## 10 · 10-hep-planner.md — HepPlanner：程序化 DSL + DAG 启发式
- 锚点：`plan/hep/{HepPlanner,HepProgram(Builder),HepInstruction,HepRelVertex,HepMatchOrder}`。
- SVG：
  - `svg/10-1-hepprogram-class.svg`【Class】HepProgram/HepInstruction 组合模式。
  - `svg/10-2-optimize-flow.svg`【Flow】optimize() 主循环 + replaceRel 原位替换。
  - `svg/10-3-dag-vs-memo.svg`【Arch】HEP DAG 单层 vs Volcano Memo 双层（引出第 11 篇）。
- 边界：Volcano（→11）。

## 11 · 11-volcano.md — VolcanoPlanner：Cascades CBO 内核 ★
- 锚点：`plan/volcano/{VolcanoPlanner,RelSet,RelSubset,IterativeRuleDriver,TopDownRuleDriver,RuleQueue,AbstractConverter,VolcanoCost}`。
- SVG：
  - `svg/11-1-driver-strategy.svg`【Class】RuleDriver 策略（Iterative/TopDown 双驱动）。
  - `svg/11-2-memo-arch.svg`【Arch】Memo：Planner→RelSet→RelSubset 分层。
  - `svg/11-3-findbestexp-flow.svg`【Flow】findBestExp 主循环。
  - `svg/11-4-cost-propagation.svg`【Seq】onMatch→register→propagateCostImprovements。
- 边界：规则体系（→12）、trait（→14）。

## 12 · 12-rules.md — 规则体系：RelRule.Config + Operand + CoreRules
- 锚点：`plan/{RelRule,RelOptRuleOperand,RelOptRule}`、`rel/rules/{CoreRules,FilterJoinRule,AggregateExpandDistinctAggregatesRule,TransformationRule,SubstitutionRule}`、`rel/convert/ConverterRule`。
- SVG：
  - `svg/12-1-relrule-class.svg`【Class】RelRule/ConverterRule 继承 + Immutables Config。
  - `svg/12-2-operand-tree.svg`【Class/Arch】RelOptRuleOperand 递归匹配树 + ChildPolicy。
  - `svg/12-3-rule-apply-flow.svg`【Flow】注册→匹配→onMatch→transformTo。
- 边界：driver 如何调度（→11）。

## 13 · 13-metadata-cost.md — 元数据与代价（RMQ + Janino provider）
- 锚点：`rel/metadata/{RelMetadataQuery,JaninoRelMetadataProvider,BuiltInMetadata,CyclicMetadataException,ChainedRelMetadataProvider,DefaultRelMetadataProvider}`、`plan/RelOptCost`、`plan/volcano/VolcanoCost`。
- SVG：
  - `svg/13-1-rmq-class.svg`【Class】RMQ 聚合 Handler + provider 链。
  - `svg/13-2-metadata-query-seq.svg`【Seq】getRowCount→handler→Janino 编译/缓存。
  - `svg/13-3-provider-chain.svg`【Arch】Janino→Chained→Default provider 链 + 循环防护。
- 边界：cost 在主循环里如何用（→11 一句话）。

## 14 · 14-trait-convention.md — Trait/Convention 与物理属性传播
- 锚点：`plan/{RelTraitSet,RelTrait,RelTraitDef,Convention,ConventionTraitDef,DeriveMode}`、`rel/{RelCollation,RelDistribution(s),RelCompositeTrait,RelMultipleTrait}`。
- SVG：
  - `svg/14-1-traitset-pool.svg`【Class/Arch】RelTraitSet 内存池 + RelTrait 多态。
  - `svg/14-2-convention-graph.svg`【Arch】Convention 转换图（NONE 星形 + ConverterRule 边）。
  - `svg/14-3-distribution-matrix.svg`【Matrix】RelDistribution.Type 对照。
- 边界：联邦查询案例落到 17/18。

## 15 · 15-linq4j.md — linq4j 与 Expression Tree（第四层 IR）
- 锚点：`linq4j/Enumerable`/`Enumerator`、`Queryable`/`QueryProvider`、`linq4j/tree/{Expressions,Expression,BlockBuilder,Shuttle,OptimizeShuttle,ClassDeclaration,ExpressionWriter}`。
- SVG：
  - `svg/15-1-enumerable-class.svg`【Class】Enumerable/Enumerator vs JDK Iterable/Iterator。
  - `svg/15-2-expr-optimize-pipeline.svg`【Flow】Expression→OptimizeShuttle→BlockBuilder(CSE)→源码。
  - `svg/15-3-blockbuilder-cse.svg`【Seq/Flow】expressionForReuse 公共子表达式消除。
- 边界：算子 codegen（→16）。

## 16 · 16-codegen-exec.md — RelNode→Java：Enumerable codegen + Janino + Interpreter
- 锚点：`adapter/enumerable/{EnumerableRel,EnumerableRelImplementor,PhysType(Impl),JavaRowFormat,RexToLixTranslator,RexImpTable,EnumerableHashJoin/Aggregate/Calc,EnumerableInterpretable}`、`interpreter/{Interpreter,Node,Nodes,Sink,Source}`、`runtime/{Bindable,ArrayBindable}`。
- SVG：
  - `svg/16-1-compile-lifecycle.svg`【Flow】implement()→ClassDeclaration→Janino→Bindable→bind。
  - `svg/16-2-phystype-rowformat.svg`【Arch/Class】PhysType + JavaRowFormat(ARRAY/CUSTOM)。
  - `svg/16-3-hashjoin-codegen.svg`【Flow】HashJoin 生成伪码结构。
  - `svg/16-4-interpreter-dataflow.svg`【Arch】Interpreter Node/Sink/Source push 数据流。
- 边界：Expression tree 本体（→15）。

## 17 · 17-extensibility.md — 扩展性架构：Schema SPI 能力分层
- 锚点：`schema/{Schema,Table,ScannableTable,FilterableTable,ProjectableFilterableTable,TranslatableTable,ModifiableTable,SchemaFactory,Wrapper,QueryableTable}`、`adapter/java/AbstractQueryableTable`、JSON model。
- SVG：
  - `svg/17-1-table-capability-pyramid.svg`【Arch】Table 能力分层金字塔（Scannable→…→Translatable）。
  - `svg/17-2-schema-spi-class.svg`【Class】Schema/SchemaFactory/Table/Wrapper。
  - `svg/17-3-federation-convention.svg`【Flow】联邦查询 Convention 转换（NONE→specific→ENUMERABLE）。
- 边界：具体 adapter 对比（→18）。

## 18 · 18-adapters.md — Adapter 生态对比（数据工程视角）
- 锚点：`adapter/jdbc/{JdbcSchema,JdbcTable,JdbcRules,JdbcConvention}`、`rel/rel2sql/RelToSqlConverter`、`sql/SqlDialect`、`example/csv/*`、`mongodb/*`、`elasticsearch/*`、`druid/*`。
- SVG：
  - `svg/18-1-quadruple-class.svg`【Class】四件套（Schema/Table/Rel/Rules）跨 adapter 对比。
  - `svg/18-2-jdbc-pushdown-flow.svg`【Flow】JDBC pushdown + RelToSql + 方言。
  - `svg/18-3-pushdown-matrix.svg`【Matrix】5 adapter × pushdown 能力热力图。
- 边界：SPI 接口本体（→17）。

## 19 · 19-design-patterns.md — 设计模式全景
- 锚点：`tools/RelBuilder`、`rel/core/RelFactories`、三层 Shuttle、`StandardConvertletTable`/`CoreRules`、`sql/type/ReturnTypes`、`rel/type/RelDataTypeFactory`、`plan/RelRule`、Immutables `Config`、`util` 惰性求值。
- SVG：
  - `svg/19-1-pattern-map.svg`【Arch/Matrix】模式→代码实例映射全景。
  - `svg/19-2-three-visitors.svg`【Class】Sql/Rel/Rex 三层 Visitor 对照。
  - `svg/19-3-relbuilder-state.svg`【Seq/Flow】RelBuilder Frame 栈状态演变。
- 边界：每个模式的机制细节链接到其主讲篇。

## 20 · 20-quality-and-modules.md — 工程质量保障 + 全模块巡礼
- 锚点：`build.gradle.kts`（werror/Error Prone/Checker/forbiddenapis/RAT/passProperty/TR-locale）、`testkit/{Fixtures,RelOptFixture,SqlOperatorFixture,QuidemTest,DiffRepository,Matchers}`、`util/{Bug,Litmus,ImmutableBitSet,Pair,TryThreadLocal}`、`runtime/Hook`；全部模块。
- SVG：
  - `svg/20-1-quality-toolchain.svg`【Arch/Flow】质量工具链（Checker→ErrorProne→forbiddenapis→checkstyle→RAT→test）。
  - `svg/20-2-test-architecture.svg`【Arch】测试体系（Fixtures/Quidem/DiffRepository/Matchers 数据流）。
  - `svg/20-3-module-tour-matrix.svg`【Matrix】全模块巡礼（≥20 模块 × 定位/能力）。
- 内容：全模块逐个短评——core/linq4j/testkit/babel/server/plus/ubenchmark + adapters(arrow/cassandra/druid/elasticsearch/file/geode/innodb/kafka/mongodb/pig/piglet/redis/spark/splunk) + buildSrc/bom，每个给"定位 + 亮点 + 可借鉴点"。

## 21 · 21-feature-pipeline.md — 三道硬菜的全链路：子查询 / CTE / 开窗函数（综合篇）☆
- 目标：唯一一篇"按特性纵切"的综合篇——把子查询、CTE、开窗函数各自走一遍五阶段全链路，并列出三者的关键一步（都在 sql2rel 阶段）。
- 定位：综合篇（番外），串联前 20 篇；每阶段通用机制只一句话 + 链接主讲篇，只展开各特性专属装置。
- 锚点：`sql2rel/SqlToRelConverter`（replaceSubQueries/substituteSubQuery/convertExists、convertWith/convertIdentifier 内联、createUnion 递归检测、convertOver/HistogramShuttle）、`rex/{RexSubQuery,RexOver,RexWindow}`、`rel/rules/{SubQueryRemoveRule,ProjectToWindowRule}`、`sql2rel/RelDecorrelator`、`sql/{SqlWith,SqlWithItem,SqlWindow,SqlOverOperator}`、`rel/core/{RepeatUnion,TableSpool,Window}`、`tools/RelBuilder`（repeatUnion/transientScan）、`schema/impl/ListTransientTable`、`adapter/enumerable/{EnumerableWindow,EnumerableRepeatUnion,EnumerableTableSpool}`。
- SVG：
  - `svg/21-1-subquery-pipeline.svg`【Flow】子查询五阶段全链路。
  - `svg/21-2-subquery-keystep.svg`【Flow】关键一步 + 相关/非相关分叉（RexSubQuery）。
  - `svg/21-3-cte-pipeline.svg`【Flow】CTE 五阶段全链路（被引用两次 → 内联两份）。
  - `svg/21-4-cte-keystep.svg`【Flow】关键一步：内联展开 vs 递归 RepeatUnion。
  - `svg/21-5-window-pipeline.svg`【Flow】开窗五阶段全链路。
  - `svg/21-6-window-keystep.svg`【Flow/Class】关键一步：RexOver → Window.Group。
  - `svg/21-7-window-exec.svg`【Flow/Seq】EnumerableWindow 执行：分桶→排序→滑帧累加。
  - `svg/21-8-fullpath-overview.svg`【Arch】总览：三特性 × 五阶段泳道，高亮各自关键一步（压轴图）。
- 边界：去关联机制本体→08；Scope/Namespace→07；规则机制→12；codegen/执行→16；四层 IR→02。本篇只讲三特性各自专属的 IR 节点与转换/消解一步。
