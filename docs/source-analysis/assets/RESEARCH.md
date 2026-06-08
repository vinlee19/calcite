# 源码探索结论（RESEARCH.md）— 写作 grounding

> 来自 6 个并行 Explore 智能体（workflow `wf_3a5a25c8-d2f`）的实地探索。**行号是探索期快照，仅作"去哪个文件找"的线索；写作 agent 落稿前必须用 Read 复核实际行号**（见 STYLE.md §3）。
>
> 区块 → 文章映射：IR→02/03/04/05/06、前端→07/08/09、优化器→10/11/12/13/14、后端→15/16、Adapter→17/18、质量&模式→19/20。

---

## A. IR 三层与类型系统（→ 02/03/04/05/06）

### A1. SqlNode AST 层（→ 03）
关键文件：
- `core/src/main/java/org/apache/calcite/sql/SqlNode.java` — 抽象基类，含 SqlParserPos 源位置、clone() 协议、unparse() 序列化。
- `core/src/main/java/org/apache/calcite/sql/SqlCall.java` — 行为委托给 SqlOperator，getOperator() 实现数据/行为分离。
- `core/src/main/java/org/apache/calcite/sql/SqlOperator.java` — name/kind/leftPrec/rightPrec + 三策略对象：SqlReturnTypeInference、SqlOperandTypeInference、SqlOperandTypeChecker。
- `core/src/main/java/org/apache/calcite/sql/SqlKind.java` — 枚举分类（EQUALS/AND/OR…），isA()/belongsTo() 集合化判断，避免频繁 instanceof。
- `core/src/main/java/org/apache/calcite/sql/parser/SqlParserPos.java` — lineNumber/columnNumber/endLineNumber/endColumnNumber。
- `core/src/main/java/org/apache/calcite/sql/util/SqlVisitor.java` + `SqlBasicVisitor.java` — Visitor double-dispatch。
- `core/src/main/java/org/apache/calcite/sql/SqlDialect.java` — unparseCall() 方言定制入口。

亮点（值得学）：数据/行为分离（SqlCall 存操作数+位置，SqlOperator 存语义）；三策略对象解耦类型规则；SqlKind 分类化避免 instanceof；SqlParserPos 点+范围双精度供错误报告；unparse 优先级（SqlOperator）与方言（SqlDialect）解耦；accept→visit double-dispatch。

### A2. RelNode 关系代数层（→ 04）
关键文件：
- `core/src/main/java/org/apache/calcite/rel/AbstractRelNode.java` — RelOptCluster/RelTraitSet/digest/rowType 缓存/唯一 id。
- `core/src/main/java/org/apache/calcite/rel/RelNode.java` — getInputs()/copy(traitSet,inputs)/getRowType()/estimateRowCount()/childrenAccept()。
- `core/src/main/java/org/apache/calcite/rel/core/{Project,Filter,Join,Aggregate}.java` — exps/condition 用 RexNode；rowType 预计算。
- `core/src/main/java/org/apache/calcite/rel/RelShuttle.java` / `RelHomogeneousShuttle.java` — Visitor 特化访问 vs 齐次委托 visit(RelNode)。
- `core/src/main/java/org/apache/calcite/rel/RelWriter.java` / `externalize/RelJsonWriter.java` — 解释计划/JSON 序列化。

亮点：不可变 + copy() 契约（改 trait/input 返回新对象，原对象供回溯）；digest 去重（基于算子类型+输入 digest+trait 签名）；RelTraitSet 物理特性追踪驱动 CBO；logical(rel/core 抽象, rel/logical 实现)/physical 分层；RexShuttle 集成做代数变换；getDigest() memoization。

### A3. RexNode 行表达式层（→ 05）
关键文件：
- `core/src/main/java/org/apache/calcite/rex/RexNode.java` — getType()/getKind()/digest 缓存/accept()。
- `core/src/main/java/org/apache/calcite/rex/RexBuilder.java` — 缓存布尔/NULL/空串等常量，makeCall()/makeInputRef() 规范化，集成类型推导。
- `core/src/main/java/org/apache/calcite/rex/RexCall.java` — operands: ImmutableList<RexNode>，nodeCount 复杂度，digest。
- `core/src/main/java/org/apache/calcite/rex/RexProgram.java` + `RexProgramBuilder.java` — exprs 公共子表达式列表，projects/condition 用 RexLocalRef 引用（DAG 共享）。
- `core/src/main/java/org/apache/calcite/rex/RexSimplify.java` — 常量折叠/谓词消除/强度简化，RexExecutor 编译期求值，RexUnknownAs 处理 NULL。
- `core/src/main/java/org/apache/calcite/rex/RexShuttle.java` / `RexInputRef.java`。

亮点：RexBuilder 规范化消重 + 常量缓存；RexProgram DAG 共享（RexLocalRef(idx) 引用，避免子表达式重复）；nodeCount 防组合爆炸；RexSimplify 三级化简 + NULL 语义；RexShuttle 递归变换（列重映射/条件下推）。

### A4. 类型系统（→ 06）
关键文件：
- `core/src/main/java/org/apache/calcite/rel/type/RelDataType.java` / `RelDataTypeFactory.java`。
- `core/src/main/java/org/apache/calcite/rel/type/RelDataTypeFactoryImpl.java` — KEY2TYPE_CACHE/DATATYPE_CACHE + Interner（Flyweight），createTypeWithNullability()/copyType()。
- `core/src/main/java/org/apache/calcite/rel/type/RelDataTypeSystem.java` / `RelDataTypeSystemImpl.java` — getMaxPrecision()/getMinScale()/roundingMode() 可定制（Hive 改 DECIMAL 精度 38 vs 默认 19）。
- `core/src/main/java/org/apache/calcite/sql/type/{ReturnTypes,OperandTypes,InferTypes}.java` — 静态工厂 + chain()/cascade() 组合器（BOOLEAN/VARCHAR_1024、family()、FIRST_KNOWN…）。

亮点：Flyweight interning（同类型对象仅一份，加速比较）；RelDataTypeSystem 策略可定制方言类型差异、无需改核心；三策略对象 chain/cascade 组合避免大量子类；createTypeWithNullability() 对 struct 递归。

---

## B. 前端流水线（→ 07/08/09）

### B1. Parser 与语法扩展工程（→ 09）
关键文件：
- `core/src/main/codegen/config.fmpp`、`default_config.fmpp`、`templates/Parser.jj`（Freemarker 变量 `${parser.class}` 参数化）。
- `buildSrc/subprojects/fmpp/src/main/kotlin/org/apache/calcite/buildtools/fmpp/{FmppPlugin,FmppTask}.kt`、`buildSrc/subprojects/javacc/.../JavaCCPlugin.kt`。
- `core/src/main/java/org/apache/calcite/sql/parser/{SqlParser,SqlAbstractParserImpl}.java`。
- `babel/src/main/codegen/config.fmpp`（自定义 SqlBabelParserImpl、扩展 140+ 关键字）、`includes/parserImpls.ftl`、`parserPostgresImpls.ftl`；`server/src/main/codegen/config.fmpp`。

亮点：Freemarker+JavaCC 组合实现"一份模板多方言"；FMPP 作为构建桥接（输出 build/fmpp/ 再交 JavaCC）；可扩展层次（default→config→babel 增量加关键字/解析方法，不改核心模板）；statementParserMethods/literalParserMethods/dataTypeParserMethods 钩子；SqlConformance 方言容差（isLiberal/allowCharLiteralAlias…）。

### B2. Validator（→ 07）
关键文件：
- `core/src/main/java/org/apache/calcite/sql/validate/SqlValidatorImpl.java`（大类，deriveType()）。
- `SqlValidatorScope.java`（resolve() 名字查询）vs `SqlValidatorNamespace.java`（getRowType() 行类型）— 双抽象。
- `AbstractNamespace.java`、`SelectNamespace.java`、`IdentifierNamespace.java`。
- `SelectScope.java`、`ListScope.java`、`GroupByScope.java`、`JoinScope.java`（继承链 SelectScope→ListScope→DelegatingScope）。
- `SqlConformance.java` 方言容差。

亮点：Scope（查询位置的名字解析语境）与 Namespace（数据源行类型）分离关注点；resolve() 链式查找委托外层 scope 支持子查询引用；Namespace 延迟类型推导 + 缓存（懒求值）；Scope 方言行为（allowGroupByAlias）；多层 Scope 继承传递 resolve。

### B3. SqlToRel（→ 08）
关键文件：
- `core/src/main/java/org/apache/calcite/sql2rel/SqlToRelConverter.java`（convertQuery() 入口；内部类 Blackboard）。
- `StandardConvertletTable.java` / `ReflectiveConvertletTable.java`（getConvertlet 按 instance→class→expr 分层查找）、`SqlRexConvertlet(Table).java`。
- `RelDecorrelator.java`（相关子查询去关联）、`AggConverter.java`、`RelStructuredTypeFlattener.java`、`CorrelateProjectExtractor.java`。

亮点：Blackboard 模式（scope/nameToNodeMap/root/subQueryList 共享状态容器）；convertQuery 主流程→去关联；Convertlet 分层查找支持继承重载；反射式注册（convertCast↔CAST）；Blackboard 实现 SqlVisitor<RexNode>；RelDecorrelator 用 Correlate 物化子查询；AggConverter 借 AggregatingSelectScope 识别 GROUP BY。

---

## C. 优化器内核（→ 10/11/12/13/14）

### C1. Volcano/Cascades（→ 11）
关键文件：
- `core/src/main/java/org/apache/calcite/plan/volcano/VolcanoPlanner.java`（findBestExp/ruleDriver.drive 主循环、initRuleQueue 选驱动、setRoot/registerImpl、buildCheapestPlan）。
- `RelSet.java`（rels/subsets、equivalentSet 并查集、conversions）、`RelSubset.java`（bestCost 动规、set 反向指针、getBestOrOriginal、isDelivered/isRequired）。
- `IterativeRuleDriver.java` vs `TopDownRuleDriver.java`（双驱动，Stack<Task>/OptimizeGroup/passThroughCache）。
- `RuleQueue.java`（addMatch/skipMatch 循环检测、checkDuplicateSubsets 防自环）、`IterativeRuleQueue.java`/`TopDownRuleQueue.java`。
- `AbstractConverter.java`（无穷成本 enforcer）、`VolcanoRuleCall.java`（transformTo）、`VolcanoRuleMatch.java`（digest）、`VolcanoCost.java`（cpu/io/rowCount + INFINITY/HUGE/ZERO 常量池）。

亮点：双驱动可插拔（RuleDriver 接口 + setTopDownOpt）；RelSet/RelSubset 分层 memo（语义等价集合 + 按 trait 分组）；循环防护 checkDuplicateSubsets；动规主循环 + canonize 合并 + buildCheapestPlan；TopDown 任务化 + passThroughCache；AbstractConverter enforcer 强制 trait；VolcanoCost 常量池复用。
pitfalls：AbstractConverter 无穷成本可能掩盖真实转换成本，过度依赖规则顺序；CyclicMetadataException 防护仅在 BuiltInMetadata 层；IterativeRuleDriver 无优先级出队可能 O(n²)。

### C2. HEP（→ 10）
关键文件：
- `core/src/main/java/org/apache/calcite/plan/hep/HepPlanner.java`（DAG 图、optimize 主循环、executeRuleClass/Collection、GC 管理 graphSizeLastGC）。
- `HepProgram.java`/`HepProgramBuilder`（ImmutableList<HepInstruction>、MATCH_UNTIL_FIXPOINT、流式 addRuleClass/addMatchOrder/addMatchLimit）、`HepInstruction.java`（RuleClass/RuleCollection/BeginGroup/EndGroup/LoopUntilFixed、prepare()）。
- `HepRelVertex.java`（currentRel 代理、replaceRel 原位替换、stripped）、`HepState.java`、`HepMatchOrder.java`（DEPTH_FIRST/BREADTH_FIRST/TOP_DOWN）、`HepRelMetadataProvider.java`。

亮点：程序化 DSL（组合 HepInstruction 列表 + 嵌套 group + prepare 延迟生成状态）；DAG 单层 vs Volcano 双层；指令执行状态机；可控循环（MATCH_UNTIL_FIXPOINT/matchLimit/MatchOrder）；轻量顶点包装；原位替换贪心；显式 GC。
pitfalls：指令序列固定无法按中间结果动态调整；currentRel 被包装隐藏需 HepRelMetadataProvider 中介；noDag 模式重复优化退化。

### C3. 规则体系（→ 12）
关键文件：
- `core/src/main/java/org/apache/calcite/plan/RelRule.java`（config 字段、Config 接口 + toRule()、Immutables `@Value.Immutable`）、`RelOptRule.java`（旧式）。
- `RelOptRuleOperand.java`（predicate、RelOptRuleOperandChildPolicy UNORDERED/ANY/SOME/NONE、clazz/trait/children 递归匹配、solveOrder/ordinalInParent）。
- `rel/rules/CoreRules.java`（157+ 规则常量，命名 AGGREGATE_/FILTER_/JOIN_）。
- `rel/rules/FilterJoinRule.java`（perform 递归 aboveFilters/joinFilters）、`AggregateExpandDistinctAggregatesRule.java`（DISTINCT 展开为多 Aggregate/Join）。
- `rel/convert/ConverterRule.java`（inTrait/outTrait）、`rel/rules/{TransformationRule,SubstitutionRule}.java` 标记接口。

亮点：RelRule.Config Immutable + 流式 withXxx；Operand 递归匹配树 + ChildPolicy；CoreRules 中央注册表；FilterJoinRule 单类处理两种模式；规则可观察性（solveOrder/ordinalInRule）；Transformation vs Substitution 二元分类；operand builder（some/none/any/unordered）。
pitfalls：Immutables 忘配注解处理器 → 运行时 ClassNotFound；Operand predicate 可选忘设 → 过度匹配；规则顺序与 PhysicalNode 过滤交互。

### C4. 元数据与代价（→ 13）
关键文件：
- `core/src/main/java/org/apache/calcite/rel/metadata/RelMetadataQuery.java`（THREAD_PROVIDERS、22+ Handler 字段、getRowCount/getSelectivity/getDistribution）。
- `JaninoRelMetadataProvider.java`（HANDLERS LoadingCache、generateCompileAndInstantiate Janino 即时编译 handler）。
- `BuiltInMetadata.java`（Selectivity/UniqueKeys/RowCount/Collation/Distribution… Handler 嵌套接口）、`MetadataDef.java`/`MetadataHandler.java`/`MetadataFactory.java`。
- `CyclicMetadataException.java`（循环检测）、`ChainedRelMetadataProvider.java`、`DefaultRelMetadataProvider.java`、`DelegatingMetadataRel.java`、`RelMdUtil.java`。
- `plan/RelOptCost.java`、`plan/RelOptCostFactory.java`、`plan/volcano/VolcanoCost.java`。

亮点：RMQ 强类型门面 + 22 Handler 代理 + 线程安全 THREAD_PROVIDERS；Janino 动态生成 handler 代理避免反射开销 + 缓存；BuiltInMetadata 接口族 + 反射分派；CyclicMetadataException 中断循环；RelOptCost 抽象 + 自定义工厂；ChainedRelMetadataProvider 有序链。
pitfalls：循环防护仅 BuiltInMetadata 层；Janino 编译缓存全局、provider 变更不失效；THREAD_PROVIDERS 线程本地未设置会 NPE。

### C5. Trait/Convention（→ 14）
关键文件：
- `core/src/main/java/org/apache/calcite/plan/RelTraitSet.java`（cache 内存池、traits[]、canonize、replace 返回新集合、== 身份比较）。
- `plan/Convention.java`（NONE 虚拟约定、getInterface、enforce 生成转换节点、canConvertConvention）、`plan/RelTrait.java`（satisfies 偏序）、`plan/RelTraitDef.java`（canonize/registerConverterRule）、`plan/ConventionTraitDef.java`（转换图预构建）。
- `rel/RelCollation.java`、`rel/RelDistribution.java`（Type: HASH/RANGE/BROADCAST/SINGLETON/ANY、getKeys、apply(mapping)）、`rel/RelDistributions.java`、`rel/RelCompositeTrait.java`、`rel/RelMultipleTrait.java`、`plan/DeriveMode.java`（LEFT_FIRST/RIGHT_FIRST/BOTH/OMAKASE/PROHIBITED）。

亮点：TraitSet 规范化 + 全局内存池（== 比较）；Convention.NONE 虚拟约定作转换前置；enforce + ConverterRule + 转换图；Collation/Distribution 多值 trait（RelMultipleTrait + RelCompositeTrait）；DeriveMode 灵活传播策略；satisfies 偏序（ORDER BY [x,y] satisfies [x]）；Distribution.apply(mapping) 列映射自适应；ConventionTraitDef 转换图最短路。
pitfalls：自定义 RelTrait 未实现 hashCode/equals → 内存池失效；多值/单值 trait 混用 ClassCastException；DeriveMode.OMAKASE 误用 → 无法满足输出特征。

---

## D. 执行后端（→ 15/16）

### D1. linq4j Enumerable/Enumerator（→ 15）
关键文件：
- `linq4j/src/main/java/org/apache/calcite/linq4j/{Enumerable,Enumerator,AbstractEnumerable,DefaultEnumerable,Queryable,DefaultQueryable,QueryProvider,QueryProviderImpl}.java`。

亮点：Enumerator（pull-based 有状态可 moveNext/current + AutoCloseable + reset）vs JDK Iterator；moveNext/current 分离支持惰性管道；Enumerable extends Iterable 兼容 foreach + asQueryable 桥接表达式树。

### D2. Expression Tree（第四层 IR）（→ 15）
关键文件：
- `linq4j/src/main/java/org/apache/calcite/linq4j/tree/{Expressions,Expression,ExpressionType,BlockBuilder,Shuttle,OptimizeShuttle,ClassDeclaration,ExpressionWriter}.java`。

亮点：Expression Tree 介于 RexNode 与 Janino 源码之间的 IR；Expressions 200+ 工厂方法 fluent builder；BlockBuilder expressionForReuse（Equivalence.identity）做 CSE；OptimizeShuttle 常量折叠/死代码消除/null 安全转换/三目简化；Shuttle preVisit/visit 双分派单遍优化；ExpressionType lprec/rprec 自动括号。

### D3. Enumerable convention codegen（→ 16）
关键文件：
- `core/src/main/java/org/apache/calcite/adapter/enumerable/{EnumerableRel,EnumerableRelImplementor,PhysType,PhysTypeImpl,JavaRowFormat,RexToLixTranslator,EnumerableConvention,EnumerableInterpretable}.java`。

亮点：EnumerableRel.Result 三元组（BlockStatement+PhysType+JavaRowFormat）；Implementor map 注入 DataContext 等全局上下文；RexToLixTranslator 把 RexNode→Expression + NullPolicy(STRICT/SEMI_STRICT/ARG0/ALL) 控制 null 传播；JavaRowFormat（CUSTOM POJO vs ARRAY Object[]）自适应。

### D4. 具体算子 codegen（→ 16）
关键文件：
- `adapter/enumerable/{EnumerableHashJoin,EnumerableNestedLoopJoin,EnumerableAggregate,EnumerableCalc,EnumerableTableScan,EnumerableWindow,RexImpTable,CallImplementor}.java`。

亮点：HashJoin 生成 Lookup + probe；Aggregate grouping().aggregate(seed,accum)；Calc filter()+select() 链；RexImpTable Map<SqlOperator,CallImplementor> 策略注册（100+ 函数）支持 UDF 扩展；JavaRowFormat.record() 按格式生成行构造。

### D5. Janino 编译与执行（→ 16）
关键文件：
- `adapter/enumerable/EnumerableInterpretable.java`（BINDABLE_CACHE，key=生成源码字符串）、`interpreter/{JaninoRexCompiler,Compiler,Interpreter,BindableConvention,InterpretableRel}.java`、`runtime/{Bindable,ArrayBindable}.java`。

亮点：BINDABLE_CACHE 以生成源码字符串为 key 避免重复编译；toBindable 全流程（implement→toString→Hook.JAVA_PLAN→Janino compile→newInstance）；JaninoRexCompiler 处理变量重名/null 类型转换/泛型擦除；Bindable（框架内、参数数组）vs Enumerable（用户 API）；DataContext 执行环境注入。

### D6. Interpreter 模式（→ 16）
关键文件：
- `interpreter/{Interpreter,Node,Nodes,Sink,Source,Context,Row,Compiler}.java`。

亮点：无 codegen 后备引擎（RelNode→Node 树直接遍历）；Node 单一职责 + AutoCloseable；Sink/Source 解耦 push-based pipeline；optimize() 初始化时 CALC_SPLIT/FILTER_INTERPRETER_SCAN 下推；Row 简化执行模型（Object[] + 列索引）。
pitfalls：函数调用开销大、cache locality 差；适合不可编译复杂算子/原型/缓存失效。

---

## E. 扩展性与 Adapter 生态（→ 17/18, 20 模块巡礼）

### E1. Schema SPI 能力分层（→ 17）
关键文件：
- `core/src/main/java/org/apache/calcite/schema/{Schema,Table,SchemaFactory,ScannableTable,FilterableTable,ProjectableFilterableTable,TranslatableTable,ModifiableTable,Wrapper,QueryableTable}.java`、`adapter/java/AbstractQueryableTable.java`、`schema/impl/AbstractTable.java`。

亮点：标记接口渐进式能力分层（Scannable→Filterable→ProjectableFilterable→Translatable），非侵入；SchemaFactory + JSON model operand 声明式装配；Wrapper.unwrap(Class) 类型安全反向查询（暴露 DataSource/SqlDialect）；Filterable/Projectable 用可变 list + removeIf 表示"已处理"，剩余由 Calcite 执行；TranslatableTable.toRel() 接入优化器规则链；Schema 多级路径解析 + SchemaPlus。

### E2. 代表性 Adapter 对比（→ 18）
关键文件：
- JDBC：`core/.../adapter/jdbc/{JdbcSchema,JdbcTable(三接口),JdbcRules(PROJECT/FILTER/JOIN_FACTORY),JdbcConvention(COST_MULTIPLIER,register)}.java` + `rel/rel2sql/RelToSqlConverter.java`（ReflectiveVisitor 分派）+ `sql/SqlDialect.java`（BUILT_IN_OPERATORS_LIST、quoting/casing）。
- CSV：`example/csv/.../{CsvSchemaFactory(Flavor),CsvTable(protoRowType),CsvScannableTable,CsvFilterableTable(addFilter),CsvTranslatableTable(toRel)}.java`。
- MongoDB：`mongodb/.../{MongoTable(toRel,动态 schema Map),MongoRules(BSON $match/$project/$group)}.java`。
- Elasticsearch：`elasticsearch/.../ElasticsearchTable.java`（版本适配、ObjectMapper、PredicateAnalyzer→ES DSL）。
- Druid：`druid/.../{DruidTable(timestampFieldName/metricFieldNames/intervals/complexMetrics),DruidRules(Filter/Aggregate/PostAggregation、时间粒度)}.java`、DruidExpressions/BinaryOperatorConversion。

亮点：四件套统一（Schema/Table/Rules/Convention+Dialect）；JDBC 最完整（Filter/Project/Join/Sort/TableModify pushdown + RelToSql 反向翻译 + 方言）；CSV 教学三 Flavor；MongoDB 动态 schema + BSON 管道；ES 版本适配 + DSL；Druid 时序聚合最复杂。
pushdown 能力矩阵：JDBC(Filter/Project/Join/Sort/Aggregate) > MongoDB(Filter/Project/Aggregate) > Druid(Filter/Aggregate+时间) > ES(Filter/Project) > CSV(仅简单 EQUALS)。
SqlDialect 策略：RelToSqlConverter 与 Dialect 分离，新方言只实现 getOperandType/getDataType/quoteString，无需改 core。

### E3. 其余模块巡礼（→ 20）
- arrow（列存二进制 OLAP/跨语言）、cassandra（partitionKeys/clusteringKeys 分区裁剪）、file（CSV/JSON/HTML 多格式 FileSchema）、geode（内存数据网格+地理）、innodb（InnoDB 引擎直读）、kafka（Topic→STREAM 表）、pig/piglet（Pig 集成/类 Pig 脚本语言）、redis（KV）、spark（DataFrame/SparkRules）、splunk（固定列+自由字段→SPL）、plus（tpcds/tpch/os 数据虚拟化）、babel（多方言转译）、server（DDL CREATE TABLE 等）、testkit（CalciteAssert/Matchers）、ubenchmark（JMH）。

---

## F. 工程质量与设计模式（→ 19/20）

### F1. 构建与静态检查（→ 20）
关键文件：`build.gradle.kts`（werror -Werror、Error Prone、Checker Framework nullness、forbiddenapis、autostyle+checkstyle、RAT 许可证、passProperty 测试属性转发、user.language=TR 土耳其语 locale 暴露 i18n、JUnit 并行、testSlow、testHepLargePlanMode）、`buildSrc/subprojects/{buildext,javacc,fmpp}`、`.ratignore`。
亮点：werror 零警告；Checker null 检查；ErrorProne+forbiddenapis 双层；autostyle 自动格式化；RAT 许可证治理；passProperty 仅转发 calcite./avatica. 前缀；TR-locale 暴露大小写 bug；并行执行 + 慢测分离；SpotBugs/Jacoco 按需。

### F2. 测试工程与 Fixture（→ 20）
关键文件：`testkit/.../{Fixtures(forParser/forValidator/forSqlToRel/forRules/forOperators/forMetadata),RelOptFixture(final 字段+with*+before/after Hook),SqlToRelFixture,SqlOperatorFixture(Impl),QuidemTest(@ParameterizedTest+@MethodSource, .iq),DiffRepository(XML golden-file,_actual.xml),Matchers(returnsUnordered/relIsValid+THREAD_ACTUAL)}.java`。
亮点：流畅工厂；不可变 fixture（with* 返回新对象，测试可安全共享）；Hook 机制注入观察器；DelegatingInvocationHandler 代理（CAST→SAFE_CAST）；Quidem .iq 参数化；DiffRepository XML golden-file + quidem.write 更新。

### F3. util 精品与防御式编程（→ 20）
关键文件：`util/{Bug(CALCITE_*_FIXED 常量追踪上游 bug),Litmus(THROW/IGNORE 验证回调),ImmutableBitSet(long[]+COMPARATOR 拓扑序),Pair(Comparable+Map.Entry),TryThreadLocal(Memo AutoCloseable 自动恢复),Util(transform/first/skipLast,@API)}.java`、`runtime/Hook.java`（enum + CopyOnWriteArrayList + threadHandlers TryThreadLocal）。
亮点：Bug 常量 self-documenting 追踪上游；Litmus 两种验证策略；ImmutableBitSet word 级位运算 + Flyweight；TryThreadLocal try-with-resources 自动恢复；Hook 全生命周期观察点 + 线程隔离。

### F4. 设计模式全景（→ 19）
关键文件与模式：
- Builder：`tools/RelBuilder.java`（ArrayDeque<Frame> 栈 + 500+ with*/build），`rex/RexProgramBuilder`，`RelDataTypeFactory.Builder`。
- 抽象工厂：`rel/core/RelFactories.java`（ProjectFactory/FilterFactory/JoinFactory… + Struct 聚合 + DEFAULT 单例可替换）。
- Visitor/Shuttle 三层：`sql/util/SqlVisitor`、`rel/RelShuttle(Impl)`、`rex/RexShuttle`、`linq4j/tree/Shuttle`。
- 注册表 Registry：`sql2rel/StandardConvertletTable`（反射注册）、`rel/rules/CoreRules`（常量池）。
- 策略 Strategy：`sql/type/ReturnTypes`（chain/cascade）、`RelDataTypeSystem`、`plan/DeriveMode`、Volcano RuleDriver。
- Flyweight：`rel/type/RelDataTypeFactoryImpl`（DATATYPE_CACHE）、`plan/RelTraitSet`（cache）。
- 模板方法：`plan/RelRule`（defines/onMatch）。
- Immutables value-object：大量 `*.Config`（@Value.Immutable 省 equals/hashCode/builder）。
