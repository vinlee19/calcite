# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

Apache Calcite is a dynamic data management framework: SQL parser/validator, an extensible cost-based optimizer, relational-algebra operators, and adapters that expose external data sources (Cassandra, Druid, Elasticsearch, MongoDB, Kafka, JDBC, Arrow, files, etc.) as queryable schemas. There is no storage layer — Calcite plans queries that other engines execute.

## Build & test (Gradle)

Use the wrapper (`./gradlew`); CI uses the same. Java 8/11/17/21/23 are supported (Java 11+ required for Error Prone).

```
./gradlew assemble                    # build artifacts, skip tests/style
./gradlew build                        # full: compile + style + tests
./gradlew build -x test                # compile + style, no tests
./gradlew check                        # style + tests
./gradlew test                         # all unit tests
./gradlew :core:test                   # tests in one module
./gradlew :core:test --tests org.apache.calcite.test.JdbcTest.testWinAgg   # single test
./gradlew testSlow                     # JUnit @Tag("slow") tests (raises heap to 6g)
./gradlew style                        # autostyleApply + autostyleCheck + checkstyleAll (auto-fix)
./gradlew autostyleCheck checkstyleAll # report-only style check
./gradlew -PenableCheckerframework :linq4j:classes :core:classes   # null-safety check
./gradlew -PenableErrorprone classes   # Error Prone (Java 11+)
./gradlew generateSources              # rerun FMPP/JavaCC parser generation
```

Integration tests (`*IT.java`) live separately and require the Vagrant test VM from `vlsi/calcite-test-dataset`:

```
./gradlew :core:integTestAll               # all DBs
./gradlew :core:integTestPostgresql        # one DB (also: H2, mysql, oracle)
```

The interactive SQL shell is `./sqlline` from the repo root.

### Test JVM properties — gotcha

Tests run in a forked JVM. Only system properties starting with `calcite.` or `avatica.` (plus a fixed allow-list in `build.gradle.kts: passProperty`) are forwarded. Setting an arbitrary `-Dfoo=bar` on the Gradle command line will not reach the test. Common forwarded toggles:

- `-Dcalcite.test.db={h2|hsqldb|mysql|postgresql}` — JDBC backend for the test suite (default `hsqldb`)
- `-Dcalcite.debug=true` — print generated Java code to stdout
- `-Dcalcite.test.splunk=true` — enable Splunk tests

JUnit Jupiter parallel execution is on by default; per-test timeout is 5 min. Tests run with `user.language=TR`/`user.country=tr`/`user.timezone=UTC` to surface locale bugs.

## Module layout (only the non-obvious bits)

- `core/` — SQL parser, validator, RelNode/RexNode algebra, planners (Volcano + Hep), JDBC driver, sql2rel, prepare. The bulk of Calcite.
- `linq4j/` — LINQ-style query expression library used to compile RelNodes to executable Java via Janino.
- `testkit/` — shared test fixtures (`SqlOperatorFixture`, `Matchers`, …) consumed by `core` and adapter modules.
- `babel/` — alternate SQL parser that accepts dialects beyond Calcite's standard grammar.
- `server/` — DDL extensions (`CREATE TABLE`, etc.) layered on the core engine.
- `bom/` — Bill of Materials publishing the dependency-version platform.
- `buildSrc/` — custom Gradle plugins (`calcite.fmpp`, `calcite.javacc`, `calcite.buildext`) that drive parser code generation.
- `example/csv`, `example/function` — adapter tutorials.
- `ubenchmark/` — JMH micro-benchmarks.
- `site/` — Jekyll source for calcite.apache.org. `site/_docs/howto.md` is the authoritative dev guide.
- Adapters: `arrow cassandra druid elasticsearch file geode innodb kafka mongodb pig piglet plus redis spark splunk`.

## Architecture: how a query flows through Calcite

1. **Parse** — `org.apache.calcite.sql.parser.SqlParser` produces `SqlNode` trees. The parser is **generated** from FMPP templates + JavaCC — see "Generated code" below.
2. **Validate** — `SqlValidator` resolves identifiers, types, scopes; produces a validated `SqlNode`.
3. **Convert to algebra** — `SqlToRelConverter` (`org.apache.calcite.sql2rel`) turns `SqlNode` into `RelNode` (relational algebra). Alternatively, build `RelNode` directly with `RelBuilder` (`org.apache.calcite.tools`).
4. **Optimize** — `RelOptPlanner` (Volcano in `org.apache.calcite.plan.volcano`, Hep in `…hep`) applies `RelOptRule`s under a cost model. Each `RelNode` carries `RelTraitSet` (convention, collation, distribution); rules transform between conventions.
5. **Implement** — converters per adapter convert logical `RelNode`s into adapter-specific physical nodes (e.g. `JdbcRel`, `MongoRel`). The `enumerable` convention compiles to Java via linq4j + Janino and runs in-process.

`RexNode` (in `org.apache.calcite.rex`) represents row-level scalar expressions; `RelNode` represents whole relations. Don't confuse the two — most planner rules manipulate both.

A schema adapter implements `Schema` + `Table` + (optionally) `RelOptRule`s to push operators down. JDBC adapter is in core; the rest live in their own modules.

## Generated code (parser) — do not hand-edit

The SQL parser is built in two stages by `:core`:

1. FMPP renders `core/src/main/codegen/templates/Parser.jj` from `core/src/main/codegen/config.fmpp` into `core/build/fmpp/...`.
2. JavaCC compiles the `.jj` into `core/build/javacc/javaCCMain/org/apache/calcite/sql/parser/impl/SqlParserImpl.java`.

If your IDE doesn't see the generated sources, run `./gradlew generateSources`. To extend the grammar, edit the templates under `core/src/main/codegen/`, not the generated output. A second parser is generated for tests under `org.apache.calcite.sql.parser.parserextensiontesting`.

## Quidem SQL tests (`.iq` files)

SQL behavior is largely covered by Quidem scripts in `core/src/test/resources/sql/*.iq` (e.g. `agg.iq`, `join.iq`, `winagg.iq`). These are dispatched by `CoreQuidemTest`/`CoreQuidemTest2`. To update expected output after an intentional change, run with `-Dquidem.write=true` (re-run the test, then commit the diff). Adapter modules have their own `.iq` suites.

## Null safety

Main code (not test code) is verified by Checker Framework. Conventions:

- Parameters/returns/fields are non-null **by default** — don't add `@NonNull`.
- Use `org.checkerframework.checker.nullness.qual.Nullable`, not `javax.annotation.Nullable`.
- For "trust me, not null" cases: `org.apache.calcite.linq4j.Nullness.castNonNull(x)`.
- For "must not be null at this point" runtime checks at boundaries: `Objects.requireNonNull(x, "x")`.
- `@MonotonicNonNull` for fields that start null and become non-null; `@RequiresNonNull` for fields already checked by the caller.
- Generic bounds default to non-null: `<T extends Number>` ≡ `<T extends @NonNull Number>`. Use `<T extends @Nullable Number>` to allow nulls.

Stub overrides for third-party annotations live in `*/src/main/config/checkerframework/*.astub`.

## Coding & contribution style

- Commit subjects: `[CALCITE-NNNN] Imperative description` — capitalized first letter, no trailing period, imperative mood ("Add foo", not "Added foo"). Mirrors the JIRA case.
- One JIRA case per PR. Squash to a single commit (`git rebase -i main`) before the final push.
- Don't force-push after a PR is >10 minutes old or has discussion, unless a reviewer asked you to.
- The build treats Java warnings as errors (`werror=true`). New deprecations and unchecked warnings will fail compilation.

## Debugging generated execution code

Calcite emits Java at runtime via Janino. To see/step into it:

- `-Dcalcite.debug=true` prints generated source to stdout.
- `-Dorg.codehaus.janino.source_debugging.enable=true` (optionally with `…source_debugging.dir=/tmp/janino`) keeps the generated sources on disk so IDE debuggers can attach.

Logging is SLF4J + Log4j; test config is `core/src/test/resources/log4j2-test.xml`. Bump `org.apache.calcite.plan.RelOptPlanner` or `…hep.HepPlanner` to DEBUG/TRACE to see planner decisions.
