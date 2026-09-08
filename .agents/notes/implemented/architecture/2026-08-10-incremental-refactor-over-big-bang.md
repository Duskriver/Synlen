# Agent Note: 采用增量重构，不做 big-bang 重构

Status: implemented

## Problem

项目恢复开发时，测试覆盖率接近零，存在多处 `presentation → data` 分层违规、reader 层逻辑集中在 UI、55 处 `print`。同时还没有开发规范：如果先大规模重构再写新代码，重构完仍会漂移。

## Decision

先建立开发规范（[docs/development.md](../../../../docs/development.md) 与 [docs/architecture.md](../../../../docs/architecture.md)），架构采用增量演进（strangler fig + Boy Scout Rule）：新代码一律按规范写，旧代码路过即修，只有成为新功能地基的区域才安排专项重构。**不做**一次性大规模重构。专项重构前必须先补该区域的测试。

## Alternatives considered

**先 big-bang 重构再开发** —— 全量统一分层后再加新功能。放弃：项目停更过一段时间，重构期间功能停滞且回归风险没有测试安全网兜底；没有规范约束，重构完写新代码仍会漂移。

**不重构、直接开发** —— 放弃：现状的分层违规、reader 层逻辑集中在 UI、`print` 残留会随功能堆叠加速腐化。

## Consequences

- 短期内代码库分层不一致（部分模块已规范、部分未修），可接受，靠 [subsystems](../) 页的"已知限制与待办"追踪。
- 新功能开发必须遵守规范，初期略慢，后期靠深模块的杠杆收益。
- 测试安全网是重构的前提条件：某区域没有测试时，先补测试再重构。
