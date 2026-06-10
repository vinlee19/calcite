#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to you under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# 只读校验脚本 — docs/source-analysis/ 系列
# 用法：从仓库根运行  bash docs/source-analysis/assets/verify.sh
# 退出码非 0 表示有失败项；全部通过打印 ALL CHECKS PASSED。
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BASE="$ROOT/docs/source-analysis"
SVG="$BASE/svg"
ART="$BASE/articles"
FAIL=0
note() { printf '  %s\n' "$*"; }
section() { printf '\n=== %s ===\n' "$*"; }

# 1. SVG well-formedness (xmllint)
section "1. SVG XML well-formedness (xmllint)"
if command -v xmllint >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do
    if ! xmllint --noout "$f" 2>/tmp/xmllint.err; then
      FAIL=1; note "FAIL well-formed: ${f#$ROOT/}"; sed 's/^/      /' /tmp/xmllint.err
    fi
  done < <(find "$SVG" -name '*.svg' -print0 2>/dev/null)
  note "checked $(find "$SVG" -name '*.svg' 2>/dev/null | wc -l | tr -d ' ') svg files"
else
  note "xmllint not found — skipping (install libxml2)"
fi

# 2. SVG 结构断言
section "2. SVG structure asserts (no foreignObject; has viewBox/xmlns/white bg)"
if grep -rl "foreignObject" "$SVG" 2>/dev/null; then FAIL=1; note "FAIL: foreignObject present (forbidden)"; fi
while IFS= read -r -d '' f; do
  grep -q 'viewBox' "$f" || { FAIL=1; note "FAIL no viewBox: ${f#$ROOT/}"; }
  grep -q 'xmlns="http://www.w3.org/2000/svg"' "$f" || { FAIL=1; note "FAIL no xmlns: ${f#$ROOT/}"; }
  grep -q 'fill="#ffffff"' "$f" || note "WARN no white bg rect: ${f#$ROOT/}"
done < <(find "$SVG" -name '*.svg' -print0 2>/dev/null)

# 3. 图片引用零悬挂 + 孤儿图检测
section "3. image refs resolve & no orphan svg"
# 3a. 每个 markdown 里引用的 svg 必须存在
grep -rhoE '\]\(\.\./svg/[^)]+\.svg\)' "$ART" "$BASE/README.md" 2>/dev/null \
  | sed -E 's/^\]\(\.\.\/svg\///; s/\)$//' | sort -u | while read -r rel; do
    [ -f "$SVG/$rel" ] || { echo "FAIL dangling svg ref: $rel"; }
  done | { grep . && FAIL=1 || true; }
# README 用 svg/ 相对(它在 BASE 根)
grep -rhoE '\]\(svg/[^)]+\.svg\)' "$BASE/README.md" 2>/dev/null \
  | sed -E 's/^\]\(svg\///; s/\)$//' | sort -u | while read -r rel; do
    [ -f "$SVG/$rel" ] || echo "FAIL dangling svg ref (README): $rel"
  done | { grep . && FAIL=1 || true; }
# 3b. 每张 svg 至少被引用一次
while IFS= read -r -d '' f; do
  bn="$(basename "$f")"
  if ! grep -rqF "$bn" "$ART" "$BASE/README.md" 2>/dev/null; then
    note "WARN orphan svg (never referenced): $bn"
  fi
done < <(find "$SVG" -name '*.svg' -print0 2>/dev/null)

# 4. 篇间相对链接存在性 (NN-slug.md)
section "4. inter-article links resolve"
grep -rhoE '\]\(([0-9]{2}-[a-z0-9-]+\.md)(#[^)]*)?\)' "$ART" 2>/dev/null \
  | sed -E 's/^\]\(//; s/(#[^)]*)?\)$//' | sort -u | while read -r md; do
    [ -f "$ART/$md" ] || echo "FAIL dangling article link: $md"
  done | { grep . && FAIL=1 || true; }

# 5. 源码引用路径存在性 (100%)
section "5. source path references exist"
grep -rhoE '[A-Za-z0-9_]+(/[A-Za-z0-9_.-]+)*/src/[A-Za-z0-9_/.-]+\.(java|kt|jj|fmpp|ftl)' \
  "$ART" "$BASE/README.md" 2>/dev/null | sort -u | while read -r p; do
    [ -f "$ROOT/$p" ] || echo "FAIL missing source path: $p"
  done | { grep . && FAIL=1 || true; }

# 6. 风格扫描（弱检查，仅告警）
section "6. style scan (warnings)"
# 术语黑名单
for bad in "关系节点" "行表达式节点为" "规划器树"; do
  if grep -rn "$bad" "$ART" 2>/dev/null | grep -q .; then
    note "WARN blacklisted term '$bad' found (prefer English class names):"
    grep -rn "$bad" "$ART" 2>/dev/null | sed 's/^/      /' | head -5
  fi
done
# 每篇必备骨架小节
for f in "$ART"/*.md; do
  [ -f "$f" ] || continue
  grep -q "对照阅读建议" "$f" || note "WARN ${f##*/}: missing '对照阅读建议' section"
  grep -q "延伸阅读" "$f" || note "WARN ${f##*/}: missing '延伸阅读' section"
done

section "SUMMARY"
if [ "$FAIL" -eq 0 ]; then echo "ALL CHECKS PASSED (warnings may exist above)"; else echo "SOME CHECKS FAILED — see FAIL lines above"; fi
exit $FAIL
