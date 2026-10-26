# SML PBT 架构与精简审计

日期：2026-10-26。范围：当前工作区；本轮只审计，不实施整改。

> **后续实施更新（2026-10-26）：** 用户随后授权的 F1–F4 已完成。已删除 Runner 无用格式化及 FlipOne/BBS 的过期 Test 依赖；manifest 只读一次；corpus 复用文件拆分和合同元数据。下文保留审计时的发现、行号与只读验证记录，F5–F7 未实施。
>
> 验证：47-case 计划及相关解析/依赖差分检查共 92 项通过；split 调用 97→28，`_parts` 调用 82→46。手写、生成、混合入口的计划与请求内容保持一致，纯手写仍不加载翻译资源。FlipOne/BBS 经现有命令各通过 1,000 个有效样本，输入与语义结果字段和修改前一致；Runner 打印对照也一致。solution/contract 文件未改动，无真实模型调用。
>
> 证据：[corpus](/home/SMLResearch/15150SMLResearch/tmp/simplification_20261026/corpus_checks.json)、[入口资源](/home/SMLResearch/15150SMLResearch/tmp/simplification_20261026/main_resource_validation.json)、[两项实际 PBT 与命令](/home/SMLResearch/15150SMLResearch/tmp/simplification_20261026/task_comparison.json)、[Runner](/home/SMLResearch/15150SMLResearch/tmp/simplification_20261026/runner_check.json)、[变更范围](/home/SMLResearch/15150SMLResearch/tmp/simplification_20261026/change_scope.json)。

## 1. 审计基线与结论

- 仓库：`/home/SMLResearch/15150SMLResearch`，Windows 对应 `\\wsl.localhost\Ubuntu-22.04\home\SMLResearch\15150SMLResearch`。
- 分支：`15150manual`；HEAD：`2c82d06411f12c945d0f8b65a1df2c331246b401`。
- 开始时已有 **21 个已跟踪文件修改、7 个未跟踪源码文件**，主要来自上一轮公共设施重构。本报告依据包含这些修改的源码，不能仅以 HEAD 推断现状。[起始状态](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/state_before.json)
- 覆盖五个 Python 主模块、配置、manifest、两个 prompt、SML 基座、所有注册任务及其依赖、接口卡、当前报告和历史实验入口。共有 **47 个 case：35 个手写 HW case、12 个模型生成合同 case**。通过 source、contract、adapter 与递归 CM 引用，128 个 task 自有 SML/签名/functor/CM 文件均可达，没有发现孤立 task 文件或缺失的 CM 输入。[装载路径清单](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/task_reachability.json)
- 第三方仅检查当前调用的接口和实现。QCheck 固定版本为 `92a43445779e6098a79175b41bba76ab90667256`，其工作区干净；没有使用其他语言的 QuickCheck 文档代替源码。
- 结束前比较了起始记录中的 **253 个源码、配置与相关依赖文件**，内容均未改变，分支和 HEAD 未改变。只新增此报告与临时证据；编译器可能正常写入忽略的缓存。[只读核验](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/read_only_verification.json)

**总体判断：上轮题目族共享已经生效。现在最适合先做的是删除无用格式化和过期依赖，再减少 Python 的重复读取与解析。没有证据支持重写 runner、建立通用 adapter 工厂或把所有 helper 搬到全局 utils。**

还有两项需要单独处理：生成合同失败时的产物字段丢失，以及 Tracker/Find150 的 predicate 支持域包含学生实现。前者是报告行为修正；后者涉及小范围装配接口调整，不能包装成单纯删代码。

## 2. 实际执行链与职责

```text
run.main：配置 → manifest → 选择 roots
  → corpus.plan：源文件快照、合同段、同文件 helper 图
  → run_plan：依赖先行，检查 helper 准入
      ├─ 手写：prepare_manual → compile_manual_contract
      └─ 生成：interfaces.select → model 请求 → compile_contract
                                            └─ 合同正文编译错误：至多一次修复
  → sml.execute：Target + runtime adapter + bindings + Data + driver
  → Generators.sample：固定输入在前，QCheck 随机输入在后
  → Runner.run / QCheck：requires → Target → ensures
  → SML 完成记录 → result.json / results.csv / batch_summary.json
```

| 位置 | 实际职责与边界 |
| --- | --- |
| [run.py:273](/home/SMLResearch/15150SMLResearch/run.py:273)、[run_plan:236](/home/SMLResearch/15150SMLResearch/run.py:236) | CLI、配置、调度、helper 准入、公共结果记录和运行快照。不会解释 task 的领域语义。 |
| [corpus.py:80](/home/SMLResearch/15150SMLResearch/corpus.py:80) | 按文件保存一次文本快照；识别 solution/manual 段及合同注释；解析显式 helper 引用、歧义和循环。当前真实依赖为 `all_even → is_even`、`hw_tails → hw_heads`。 |
| [interfaces.py:14](/home/SMLResearch/15150SMLResearch/interfaces.py:14)、[model.py](/home/SMLResearch/15150SMLResearch/model.py) | 只为生成路线选择声明的接口卡；构造请求、验证外部响应、保留指标。模型收到规格及已准入 helper 信息，不收到学生实现。 |
| [sml.py:89](/home/SMLResearch/15150SMLResearch/sml.py:89)、[execute:156](/home/SMLResearch/15150SMLResearch/sml.py:156) | 先编译 predicate functor，再装配运行时 Target、helper 域检查、适配器和 QCheck。当前 `support_cm` 同时进入两侧；其两个例外见 F6。 |
| [Generators.sml:29](/home/SMLResearch/15150SMLResearch/sml/Generators.sml:29) | 统一 seed、固定输入和随机输入拼接；随机数和组合器来自固定版本 QCheck。47 个 case 都经过这一采样入口，41 个使用 Data，6 个使用内置基础生成路径。 |
| [Runner.sml:33](/home/SMLResearch/15150SMLResearch/sml/Runner.sml:33) | QCheck 负责迭代和性质执行；Runner 增加阶段、实际调用次数、失败输出及机器可读结果。不是另一套随机测试引擎。 |
| `tasks/*/Data`、`Target`、`Model`、合同 | 分别承担输入分布/打印、真实调用/观察、独立预期语义、Boolean 判断。共享表示和独立 oracle 不能混为一体。 |

`target_wrapper` 和 `data_adapter.file` 已支持按顺序列出的多个文件，并由 [sml.py:34](/home/SMLResearch/15150SMLResearch/sml.py:34) 拼接为运行快照。它们不进入 predicate CM。直接 helper 参数与传递运行依赖分别由 [run.py:215](/home/SMLResearch/15150SMLResearch/run.py:215) 和 [run.py:220](/home/SMLResearch/15150SMLResearch/run.py:220) 处理，作用域不同，应保留。

## 3. 确定发现与最小整改

下表按适合实施的先后排列；F6 的隔离价值较高，但接口风险也更高，应最后实施。所有整改均为建议，本轮未修改被审计实现。

| 编号 | 结论 | 分类 | 证据 | 影响 |
| --- | --- | --- | --- | --- |
| F1 | 删除无人使用的 QCheck 状态输入格式化 | 确定可以删除 | 源码 + 临时 SML 对照 | 一处参数；低风险 |
| F2 | 删除两个过期 course Test 依赖边 | 确定可以删除 | 静态引用与实际 solution 段核对 | 两个 task；低风险 |
| F3 | manifest 只加载一次 | 确定可以复用 | 源码 + 文件读取计数 | Python 资源加载；低风险 |
| F4 | 复用已拆分的 task 段和合同元数据 | 确定有重复；合并需保持解析语义 | 完整 plan 的插桩计数 | corpus 内部；中等风险 |
| F5 | 从现有记录统一取得最后一次编译产物 | 可以简化，包含报告修正 | 本地 stub 复现 | 三个失败结果字段 |
| F6 | 分开纯支持库和学生运行依赖 | 职责明确，但有接口取舍 | 四次 compile-only 验证 | 两个 task + CM 装配 |
| F7 | 修复两条失效的当前 README 链接 | 确定可以删除旧引用、复用现有说明 | 源码与路径核查 | 文档，无运行影响 |

### F1. Runner 格式化了被回调丢弃的输入字符串

**位置与调用：** [Runner.sml:90](/home/SMLResearch/15150SMLResearch/sml/Runner.sml:90) 向 `QCheck.cpsCheck` 传入 `(next, SOME showInput)`；[onStatus:80](/home/SMLResearch/15150SMLResearch/sml/Runner.sml:80) 忽略第一个参数。固定版本 [QCheck.sml:26–34](/home/SMLResearch/15150SMLResearch/vendor/qcheck/src/QCheck.sml:26) 仍会计算该字符串。正式 driver 在 [sml.py:211](/home/SMLResearch/15150SMLResearch/sml.py:211) 已调用 `Runner.writeInputs`，反例又由 `Runner.sml:64` 单独打印。

**为什么可删、复用什么：** 这一份状态文本没有消费者。输入文件和反例的已有打印路径各有用途，保留即可。

**最小修改：** 将上述参数改为 `(next, NONE)`；不新增 helper，不动序列化规则、采样、计数或停止逻辑。当前注册的 printer 只计算描述文本。对未来带副作用的 printer，调用次数会改变，不能声称保留任意副作用。

**验证与收益：** 临时重命名副本只改该参数：2 个通过样本的 printer 调用由 2 降为 0；1 个失败样本由 2 降为 1。对应状态、计数、反例和异常字段相同，失败仍调用 target 两次。这里计数只含 Runner 内的调用，不含正式 driver 保存 inputs 的打印。实施时保留此对照，再比较一个代表性 task 的输入和结果即可。收益是删去每次状态通知的一次无用格式化；没有测得或承诺耗时提升。[运行证据](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/unused_status_display_repro.json)

### F2. FlipOne 与 BBS 保留了不再使用的 Test 依赖

**位置与调用：** [manifest:943](/home/SMLResearch/15150SMLResearch/tasks/manifest.json:943) 的 `hw_flip_one.support_cm` 引入 `course/sources.cm`；[bbs/support.cm:5、9](/home/SMLResearch/15150SMLResearch/tasks/hw/support/bbs/support.cm:5) 导出 `Test` 并引入同一课程库。它们经 predicate/runtime CM 装配加载。

**为什么可删、复用什么：** 当前提取出的 FlipOne solution 为 18 行、BBS 为 12 行，均无 `Test`/`MakeString`；其合同、Data、adapter 也不用这些名称。原 HWANS 的示例断言没有迁入这些 active solution 段。真正的 PBT 仍由既有 QCheck/Runner 执行，BBS 的前缀读取已复用 `LazyObserve.fronts`。

**最小修改：** 删除 FlipOne 的该 manifest 字段；删除 BBS 的 `structure Test` 导出和课程 CM 导入。不要删除课程库本身：[induction.sml:15](/home/SMLResearch/15150SMLResearch/tasks/hw/induction.sml:15) 等位置仍实际调用 `Test`。不修改任何学生断言或 solution。

**验证与收益：** 本轮是静态确认，没有运行删依赖后的任务。实施时编译这两个未改动的 solution/合同，各运行一次既有 seed 并比较输入与结果，包括固定样本。范围仅两个 task，收益是减少无效依赖和导出，不承诺性能收益。

### F3. 生成合同路线重复读取同一个 manifest

**位置与调用：** [run.py:45–53](/home/SMLResearch/15150SMLResearch/run.py:45) 的 `load_resources` 总会读取 manifest。`main` 在 [284](/home/SMLResearch/15150SMLResearch/run.py:284) 先加载 cases，完成选择和 `corpus.plan` 后，又在 [290](/home/SMLResearch/15150SMLResearch/run.py:290) 为生成路线调用整个 loader。

**为什么可合并、复用什么：** 第二次实际只需要接口目录和两个 prompt，却再次解析 JSON、重建 `cases`；已建立的 plan 不会因此重建。现有第一次读取的 cases 就是权威快照。

**最小修改：** 将延迟加载限定为翻译资源，保留首次 cases；删除重复 manifest 读取及相应开关分支，或保留原公共 loader、增加一个很小的翻译资源函数。不要加通用缓存服务，也不要让纯手写路线提前读 prompt 或回退到模型。

**验证与收益：** 本地插桩确认当前读取 manifest 两次。实施后对手写、生成、混合计划检查一次读取、相同 case 顺序和请求内容；无需模型请求。收益是一个明确的 manifest 快照和更小的 loader 职责，不是声称当前 I/O 已成为瓶颈。[证据](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/python_flow_evidence.json)

### F4. corpus 缓存了文本，但重复拆分同一 task 和解析同一合同

**位置与调用：** [corpus.py:106–109](/home/SMLResearch/15150SMLResearch/corpus.py:106) 已缓存磁盘文本；`source_info` 在 [114、124](/home/SMLResearch/15150SMLResearch/corpus.py:114) 拆分，随后 [127](/home/SMLResearch/15150SMLResearch/corpus.py:127) 经 `manual_text_for_case:43` 再拆一次。手写合同先在 [128–129](/home/SMLResearch/15150SMLResearch/corpus.py:128) 提取/解析，再在声明扫描 [138–146](/home/SMLResearch/15150SMLResearch/corpus.py:138) 解析。调用者是全批次和按 case/file/group 的 `corpus.plan`。

**证据与判断：** 47 个 roots 的真实 plan 无错误；28 个文件各只读一次，但 `split_task_file` 调用 97 次、`_parts` 调用 82 次。Polysort、Book 各拆分 9 次；35 个手写 case 的合同均在两条路径中解析。问题是重复解析，**不是重复磁盘读取**。[计数与依赖结果](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/corpus_parse_counts.json)

**最小修改：** 在现有按文件缓存中同时保留原文、solution、manual sections；选择 case 时直接查已拆分的段。保留一次合同扫描的元数据，供 manual case 和 helper declarations 共用，删去重复的 split 与 `_parts` 调用。不引入完整 SML parser、AST 层或跨运行缓存。

**风险、验证与收益：** 必须保留所有合同声明（包括未注册 helper）、原模型合同的优先级、别名歧义、marker 错误和首次出现顺序。不要顺手删掉 [sml.py:136、158](/home/SMLResearch/15150SMLResearch/sml.py:136) 的边界解析：公开编译/执行函数仍可能直接接收完整组合文件。实施时比较完整 47-case plan 和现有缺段、歧义、循环等临时夹具。收益是减少同一语法规则的重复处理；文件较小，没有量化加速结论。

### F5. 两种 preparation 结构导致生成合同失败时丢失产物字段

**位置与调用：** [translate:92–107](/home/SMLResearch/15150SMLResearch/run.py:92) 将编译记录放在 `attempts[i].compile`，失败返回 `compiled=None`；[prepare_manual:113–128](/home/SMLResearch/15150SMLResearch/run.py:113) 将记录放在顶层 `compile`。共同的 [run_case:170](/home/SMLResearch/15150SMLResearch/run.py:170) 只取 `compiled or preparation.get("compile", {})`。

**实际影响：** 生成合同最终编译失败或超时后，`result.json` 的 `contract_path`、`predicate_cm`、`module_name` 为空，即使 `translation.json` 已有它们。手写失败路径能保留。用真实调度代码和假的模型/编译返回值复现了两次编译失败；没有发模型请求或制造真实编译错误。[证据](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/python_flow_evidence.json)

**最小修改：** 在结果构造边界，从现有 manual compile 或最后一个带 compile 的 attempt 取得产物视图，替换当前猜测表达式。复用原记录，不在多处复制完整 diagnostics。不合并手写/生成来源、重试和错误政策，不增加状态机。

**风险、验证与收益：** 这是明确的输出修正：三个原本为空的字段将有值；不是严格保持所有输出不变的精简。验证初次/修复成功、失败、超时、从未编译的模型拒绝、初次编译后模型失败、手写失败。用合成返回记录即可；不得把旧编译产物误说成已执行成功。收益是失败可追踪、结果映射只有一个明确规则。

### F6. Tracker/Find150 的共享支持 CM 把学生实现带入 predicate

**位置与真实调用：** [_compile_predicate:89–97](/home/SMLResearch/15150SMLResearch/sml.py:89) 导入 case/direct helper 的 `support_cm`；[execute:215–223](/home/SMLResearch/15150SMLResearch/sml.py:215) 运行时再次导入。Tracker 的 [support.cm:5–15](/home/SMLResearch/15150SMLResearch/tasks/hw/support/tracker/support.cm:5) 导出并装载学生 `Utils/MkTracker`；Find150 的 [support.cm:2–21](/home/SMLResearch/15150SMLResearch/tasks/hw/support/find150/support.cm:2) 包含学生 Book、Polly/Honk/Reset 和组合/reader functor。两个 case 需要这些依赖执行真实 solution。

**问题与界限：** 一个字段同时承担公共类型/纯模型和学生实现依赖。合同虽然不能直接看见运行时 `Target`，却能通过这些公共名称调用学生实现，绕过显式 Helpers 边界。[README:113](/home/SMLResearch/15150SMLResearch/README.md:113) 的“不加载学生实现”描述因此不完全成立。当前真实合同分别使用独立的 `TrackerModel` 和页面计数性质，**未发现已经用学生实现生成 expected result**。

**运行证据：** 临时合同直接实例化 `MkTracker(Utils)`、或组合原 Book/reader 时均能编译；对照删除各自 support CM 后，均因学生名称未绑定而失败。共 4 次现有 `compile_manual_contract` 调用，0 个 PBT 样本、0 次模型请求。[源码、CM 与日志索引](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/predicate_support_exposure/summary.json)

**最小整改：** 新增一个可选的 `runtime_support_cm` 字段，仅在现有 `execute` 的运行依赖闭包中消费。Tracker 的 shared CM 只留类型和纯模型；原 Utils/MkTracker 移至 runtime CM。Find150 的学生依赖 CM 改为 runtime-only，其合同只需 Basis/Spec。更新两个注册项和字段说明。删除 shared CM 中学生实现的导入/导出，保留原算法、接口和 oracle。现有运行 wrapper 不能直接替代顶层 functor 装载，也不要将 functor 强行嵌入 `structure Target`。

**风险、验证与收益：** 影响两个 case 和 CM 装配，要保持 Seq、Book 的类型身份及 functor 参数一致；未来作为 helper 时也要传递 runtime-only 依赖，但不能进入 predicate。验证实际合同仍编译、临时越界合同不能编译、两个目标照常运行、同 seed 输入及既有结果相同。收益是明确依赖归属和恢复声明的隔离边界；会增加少量配置能力，不承诺净减少行数。

### F7. 当前 README 链接指向已移除的 Sequence 文档

**位置与消费者：** [README:36](/home/SMLResearch/15150SMLResearch/README.md:36) 指向不存在的 `sequence/README.md`；[README:152](/home/SMLResearch/15150SMLResearch/README.md:152) 指向不存在的 `tasks/sequence/README.md`。它们位于当前使用/接入说明，不是历史报告引用。

**最小修改与复用：** 改指现有 [Sequence 接口卡](/home/SMLResearch/15150SMLResearch/interfaces/sequence_cmu150.md)、[Data](/home/SMLResearch/15150SMLResearch/tasks/sequence/Data.sml)、manifest 或主 README 段落。删除旧链接，不为满足链接再新建两份重复说明。

**影响、验证与收益：** 仅改变导航；检查当前 README/接口卡的本地目标存在即可，不需 PBT。源码与文件存在性已确认。收益是消除失效入口和重复文档维护需求。

## 4. 已解决的问题：不要再次重构

| 先前线索 | 当前事实与归属 |
| --- | --- |
| Regex AST 转换重复 | [RegexTarget.regex](/home/SMLResearch/15150SMLResearch/tasks/hw/support/regex/RegexTarget.sml:2) 已供 Match/Accept/Both 复用，留在题目族的 runtime 文件。 |
| CPS 树转换重复 | [CpsTarget.tree](/home/SMLResearch/15150SMLResearch/tasks/hw/support/cps/CpsTarget.sml:2) 已供 FindOne/FindN 复用，未放进 predicate 支持库。 |
| lazy tree map 依赖 EncryptionCase.affine | 已改为全项目小模块 [Affine.apply](/home/SMLResearch/15150SMLResearch/sml/Affine.sml:4)，Encryption 和 lazy tree map 通过各自 CM 引用。 |
| 树生成与打印重复 | [IntegerTreeData](/home/SMLResearch/15150SMLResearch/tasks/hw/support/datatypes/TreeData.sml:2) 已供 symmetry/lazy tree map 复用；[TreeDisplay](/home/SMLResearch/15150SMLResearch/tasks/sequence/TreeDisplay.sml:2) 已供独立 Tree/Sequence of Tree 复用。不同题目的深度与分布仍在 Data 中。 |
| Book current/flip/trace 重复观察 | 已复用 [BookTarget.seek/step](/home/SMLResearch/15150SMLResearch/tasks/hw/support/book/BookTarget.sml:3)。Bind 遇异常停止且观察调用不同，不能直接套用 step。 |
| BBS 又写 stream 前缀读取 | [BBS Target](/home/SMLResearch/15150SMLResearch/tasks/hw/support/bbs/Target.sml:2) 已复用 `LazyObserve.fronts`；cycle/interleave 同样复用。 |
| homework 与 sequence 各自造容器库 | 都使用同一课程 Seq；已有 `Generators.sequence`、`Runner.sequence`。矩阵相关的依赖维度生成有不同约束，不是独立 nested sequence 生成的副本。 |

新公共代码的归属规则已足够：通用且表示独立的小能力放现有 `sml`；同题族转换留题目族 runtime；独立 oracle 和单题观察留 task。短 `List.map`、两整数生成器、几行 contract 接口声明无须进一步包装。

## 5. 相似但应保持独立的逻辑

### QCheck 与 Runner

固定版本 QCheck 的 stats 提供有效计数与 tags，不包含项目全部诊断。以下状态都有真实路径，不能仅因“库也有计数器”而删除。

| 状态/检查 | 条件是否已由上游保证；删除影响 |
| --- | --- |
| `stop/next` | QCheck 默认在失败后继续；项目要求首个失败停止。删除会改变样本与调用数量。 |
| `attempted/discarded/passed` | QCheck 的有效数不能区分丢弃、通过、异常，不能直接替换这些结果字段。 |
| `targetCalls` | 空 shrinker 仍会确认失败输入，实际调用数不等于 accepted。 |
| `previousCount` | requires 异常可在 QCheck status/finish 前退出；需保留此前有效数。普通完成路径仍使用 QCheck stats。 |
| `output/firstError`、阶段 handler | QCheck.pred 会将异常转成性质失败；项目需保留原异常、发生阶段和结果。清空 output 防止错误引用前一输入的输出。 |
| 局部 `RequiresError` 与 `valOf firstError` | 该异常只在记录错误后抛出，SOME 已由这条路径保证，不需新增 fallback。 |
| `validTarget > 0` 与 helper 准入 | 上游没有统一保证目标数为正。不能把零测试或不完整结果当作通过，更不能只看一个 status 字符串就准入 helper。 |

上述分支用六个小场景实际复现：通过前先丢弃、普通失败、target 异常、ensures 异常、已有通过后 requires 异常、全部丢弃。普通 false、target 异常和 ensures 异常三个场景均有 `accepted=1, target_calls=2`；requires 异常场景则为 `accepted=1, target_calls=1`。当前 [Runner:90](/home/SMLResearch/15150SMLResearch/sml/Runner.sml:90) 的 shrinker 是空列表；启用 shrinking 会改变输入、调用数与报告，应另立功能修改，不能作为去重。[运行记录](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/qcheck_boundary_repro.json)

### 输入语义、观察与 oracle

| 能力 | 应保留的区别与真实需求 |
| --- | --- |
| HOF 输入描述 | 多项式描述保证有限支撑及负指数为零；Affine、合法等价关系、CPS-total 描述各有语义。打印和重放需要普通数据，裸 closure 不能替代。 |
| QCheck stream / 课程 stream | QCheck reader 状态是随机采样状态，课程 `Stream.t` 是被测值。前者不能替代后者的构造、force 计数与观察。 |
| `LazyObserve.fronts` / `LazyModel.observe` | 一个真实 force，另一个按描述算预期。`[]` 是预算耗尽，`[NONE]` 是观察到 Empty。课程 `Stream.take` 的短流异常语义不同；`toList` 可能不终止。 |
| interleave 的首元素代码 | 必须在继续消费 tail 前保存 right 计数。与通用 fronts 相似的几行有明确时点职责；不能为去重丢掉快照。 |
| lazy 的 refs、delay/expose | refs 记录实际求值；构造检查只覆盖该观察时点，不证明每一步最少计算。不能引入原来没有的 memoization。 |
| regex continuation | 布尔表与合法后缀位置对应；对错误目标传入非后缀的检查构造 total continuation，未被正确目标假设保证。删除会改变故障表现。 |
| exceptions | Cnot 的 Break/Continue/Return 是规定的控制结果；Book 仅捕获规定的 OutOfBounds；Encryption 将 exn 当数据而不抛出。不能统一成“捕获所有异常并通过”。 |
| 循环与规模 | Cnot 的单调更新/退出条件是生成的可终止程序义务；深度、长度、观察预算是成本设置。不能把所有规模上限塞进原题 requires。 |
| helper 域检查 | 先前有限采样通过不保证当前 helper 输入满足 requires；运行时检查和 `DependencyDomainViolation` 仍必要。 |
| independent model | Regex 位置语义、Tracker 路径模型、partition 枚举、sublist sums 等不得复用学生核心算法来“减少重复”。 |
| 集合/排序 | set-like subset、多重集、严格 comparator 顺序、整数非降序各不同。`Spec`、`OrderSpec`、`SeqSpec` 的现有边界合理。 |

多项式下标检查表达表示语义，`Real.isFinite` 拒绝错误的非有限结果；heads/tails 的范围检查既保证 `take/drop/nth` 安全，也表达最大前缀，不能因 helper 已采样就删除。Encryption 内部固定非空 key 三元组保证 `hd keys` 有值，无需再增加无意义空分支。具体位置及调用核查保存在 [task 支持审计](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/task_support_findings.md)。

### Python、配置与异常边界

| 范围 | 核查结果 |
| --- | --- |
| 初次/修复与手写/生成 | 初次和修复已共享一个循环；手写/生成已共享 `run_case`、执行和结果 schema。来源证据、修复资格不同，不值得合成更大状态机。 |
| 接口选择 guards | JSON 和 corpus 不保证 interface 列表、ID、文件有效；检查提供 case/ID/path 上下文。去重保持第一次出现顺序，不是冗余校验。 |
| 模型响应 guards | 外部 HTTP/JSON 不因请求带 schema 就可信。完成标志、截断、状态、非空表达式、有限非负指标检查各有职责；保留网络错误与格式错误区别。 |
| SML 进程/编译错误 | `run_sml` 只将真实超时转为 timeout；非零退出/缺完成记录仍暴露工程错误。`compile_contract` 仅允许模型修复生成正文的错误，不能把库/类型配置错误一并送去修复。 |
| 元数据投影 | 结果的 helper 摘要不含合同正文，模型投影含合同且排除实现；两个短投影无需通用字段映射器。 |
| 路径 | source 是 manifest-relative；support/data/wrapper 是 project-relative；接口文件是 index-relative。属于既有约定，不是三个重复 path 实现。 |
| 字符串/JSON | Python JSON、CSV 单元格编码、SML 字节字面量转义、Runner JSON 打印不同，不能合为一种 escape。 |

当前根配置的 `manifest/output_dir/model/ollama_url/model_options/seed/valid_target/max_attempts/http_timeout/sml_timeout/think/keep_alive/interfaces.index` 均有消费者。PBT seed 与模型 seed 控制不同随机来源；`model_options` 整体交给后端，不能按 Python 未读某个嵌套键判死。`think=false`、`keep_alive=0` 与缺省不同。manifest 的 `data_origin/review_status` 是来源记录，非废弃开关。`generator_options.sort_lists` 暂无 active case，但仍是 README 声明且有实现的接口，不据此删除。[配置消费与 guard 明细](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/python_flow_notes.md)

## 6. native arrow、历史文件与未确认候选

**arrow 已核查，不建议替换当前函数描述。** [BaseGeneratorFn.sml:122–129](/home/SMLResearch/15150SMLResearch/vendor/qcheck/src/BaseGeneratorFn.sml:122) 捕获拆分的状态，却返回原状态 `(g,r)`。普通 `vector` 连续生成函数因此不推进这一步状态。实际用 seed 150 和 1234567890，通过固定长度 `G.lift 3` 各生成 3 个 `int → int`，在 `[-2,-1,0,1,2,9]` 上观察：同组的三行分别完全相同，且返回 RNG 状态不变；普通整数生成会变化。若长度生成器本身耗用随机状态，整个 vector 的状态仍可能变化。第二组观察为 `[-100,-100,15,-100,-100,-100]`，所以不能宣称 arrow 总生成常函数。有限 probes 也不是函数相等证明。当前 task 没有调用 arrow；这是未来复用的限制，不是当前 task 失败，也不在本轮修改 vendor。[源码与运行说明](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/sml_qcheck_audit.md)

**接口卡缓存有取舍，暂不列为必改。** `interfaces.select` 在 12 个生成 case 上读取 5 张不同卡共 23 次。run 内缓存可以固定快照、减少读取，但增加缓存归属和参数，并改变批处理中途修改卡片的效果；没有瓶颈证据。保持目前直接、只读选中卡的实现也合理。

**Tracker 的答案副本不能直接删。** [tracker.sml:2–87](/home/SMLResearch/15150SMLResearch/tasks/hw/tracker.sml:2) 明示完整 functor 是展示副本；[manifest:915、922](/home/SMLResearch/15150SMLResearch/tasks/manifest.json:915) 实际使用 Source bridge/HWANS functor，并只从 task 文件取合同。两份答案目前内容相同，[hash 记录](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/tracker_copy_identity.json) 已保存。保留答案是用户接受的布局，不能把它报成死代码或当前错误执行。F6 只修作用域，不自动消除双来源；若以后要求单一可编辑来源，需要额外评估顶层 solution 快照装配，此次不建议扩大接口。

**无调用者不等于无用途。** 没有确认可直接删除的 active Python 顶层函数、配置字段或 task 模块。调用核查同时考虑 Python、manifest 字符串、CM、生成模板与正式入口，未把缺少直接文本调用当证据。

| 文件类别 | 处理结论 |
| --- | --- |
| `runs/*` 的 Target、predicate、bindings、inputs、日志/结果 | 每次运行的隔离与复现产物，不是并行维护的生产实现；保存的 candidate 数量不等于实际有效检查数。 |
| `evaluation/*` 的 source snapshots、旧合同、实验脚本 | 有日期的研究证据。旧脚本可能依赖冻结 API，不能因主入口不调用就删除，也不能保证可直接用当前 API 重跑。 |
| 原作业、HWANS、教授报告 | 分别是题意、答案和历史结果，不能按 production reachability 清除。报告里的代码摘录不是另一份被执行算法。 |
| `.cm` 缓存、`tmp/*` 的临时验证 | 构建/研究产物，单独分类；不统计为重复生产代码。 |
| Sequence MLton 文件、安装脚本 | 对应编译/环境用途，不是第二套 PBT runner；本轮没有执行安装器或无关 MLton 实验。 |

历史脚本已逐一分类，共 14 份 Python 及安装脚本。两份旧 evaluator 仍调用五个位置参数的 `run_case`，与当前接口不兼容；旧 semantic/forced-witness driver 期待 `structure Contract`，也不能直接处理当前命名 functor。这些是已确认的历史复现接口漂移，不是 active 入口故障。若再次执行实验，应先说明匹配的 revision/合同格式，或只更新该次需要的 driver，不增设永久兼容层。helper-first 与 manual 检查分别覆盖调度和无模型回退等不同义务，不建议作为重复测试删除。[文件、调用与行号清单](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026/historical_scripts.md)

接口目录的全部目标文件存在；未被 active case 选中的 Set 卡是可选说明，不能据此判废弃运行路径。几处 `identify` 的短索引组合、整数求和和 `List.map` 行为观察没有足够收益支持新增公共 API。

## 7. 验证范围与限制

| 实际做过的检查 | 结果与边界 |
| --- | --- |
| 当前 47-case plan、依赖/CM 可达性、配置消费核查 | plan 无错误；28 个源/合同文件一次磁盘读取；128 个 task 文件可达。不是全部 task 正确性证明。 |
| Python 文件读取插桩 | 确认 F3、F4；没有模型请求。 |
| 真实调度 + 合成模型/编译返回 | 确认 F5 的字段丢失。记录中的两次 stub 调用不是两次真实模型调用。 |
| Runner 六种小场景、打印临时副本对照、两种 seed 的 arrow | 确认状态语义、F1 和 arrow 状态行为；仅临时程序，不是新增永久 suite。 |
| Tracker/Find150 四次 compile-only | 带共享依赖可引用学生模块；移除后不可引用。没有执行这两个 task 的 PBT。 |
| 只读 hash/分支核验 | 起始记录的 253 个文件均未改变；用户已有修改保留。 |

本轮 **没有调用真实模型、没有运行整仓 PBT、没有声称完成整改后的回归**。F2 的删依赖运行验证、F3/F4 的重构等价性和 F6 的隔离迁移验证仍属于实施阶段。已有 `hw_book_flip`、`hw_book_trace`、`hw_lazy_interleave` 的反例是此前运行证据，不作为本轮新发现或精简造成的故障。历史实验也不以本轮有限检查重新背书。

临时证据统一位于 [architecture_audit_20261026](/home/SMLResearch/15150SMLResearch/tmp/architecture_audit_20261026)。各项 JSON 与原日志区分真实 SML 执行、Python 插桩和合成返回值；未建立通用测试或 benchmark 框架。

## 8. 分批整改顺序

| 批次 | 文件与删改内容 | 可能影响 | 最小验证 |
| --- | --- | --- | --- |
| 1：明确无用项 | F1 的 Runner 参数；F2 的 manifest/两个 BBS CM 条目；F7 的两条 README 链接 | 去掉无用打印/依赖/导航，不改题意 | 已有打印对照；FlipOne/BBS 现有命令各跑一次；链接存在性 |
| 2：复用已经读取的数据 | F3 的 `run.load_resources/main` | 资源加载时点；保持纯手写不读模型资源 | 手写/生成/混合计划的读取次数及内容对照，无模型请求 |
| 3：小范围元数据共用 | F4 的 corpus 文件拆分和合同记录；F5 **另作报告修正** | 解析错误/顺序；失败字段从空变成真实路径 | 完整 plan 及现有解析夹具；合成编译结果矩阵，不重跑模型实验 |
| 4：最后调整装配边界 | F6 的 `sml.execute`、两组 CM、两个注册项及说明 | runtime-only 依赖、SML 类型身份、helper 传递闭包 | 隔离正/负编译对照；两个原任务的同 seed 输入/结果比较 |

没有必要再增加一批“通用 helper 抽取”。已确认的共享点已经存在；其余短组合或不同语义代码应保留。每批结束先核对输入、结果和必要边界，再决定是否继续，避免一次性重写主流程。
