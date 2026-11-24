# Refactor plan: split bloated files, fix stale code and smells

Date: 2026-11-24. Branch: `chore/clean-up` (from `main` @ `add1ab4`).
Skills used: `refactor-split` (mechanics, phases) and `solid-check` (review).

## 0. Baseline

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **304 passed**, 0 failed |
| Hand-written Dart in `lib/` | 14,529 lines, 9 files over the 400-line target |
| Tests | 20 files, 4,934 lines |

Run on Linux: `LD_LIBRARY_PATH=~/development/libs ~/development/flutter/bin/flutter test`.

Every step below must keep this at **304+ green, 0 analyzer issues**. If a step fails, revert it. Don't patch forward.

### Files over target (~400 lines/file, ~300 lines/class)

| File | Lines | Main problem |
|---|---|---|
| `lib/core/db/repository.dart` | 1989 | 11 domains in one class, plus 7 view models and all the pure budget pace logic |
| `lib/features/transactions/tx_editor_screen.dart` | 1049 | the State class holds rules, actions and layout; 5 private pickers |
| `lib/features/budgets/budget_screen.dart` | 900 | screen, card, shared pace widgets and editor sheet |
| `lib/features/stats/stats_screen.dart` | 886 | 5 independent sections and their private providers |
| `lib/features/funds/fund_screen.dart` | 862 | list, transfer sheet and editor sheet in one file |
| `lib/features/stats/category_detail_screen.dart` | 705 | screen, chart card and a 240-line `CustomPainter` |
| `lib/features/backup/backup_service.dart` | 594 | export, CSV, import and validation |
| `lib/features/home/dashboard_screen.dart` | 560 | 6 sections and `QuickActionSheet` (used by `home_shell`) |
| `lib/features/templates/template_screen.dart` | 495 | list, chips and editor sheet |
| `lib/features/transactions/split_bill_section.dart` | 419 | `SplitState` logic mixed with widgets |

---

## 1. Correctness bugs (fix first, each in its own `fix:` commit, test first)

These are behaviour changes. They are **not** part of the refactor commits.

### B1. Archiving a wallet that holds a fund counts the fund twice
- **Where:** `wallet_list_screen.dart:184` (archive action) and `:212` (the "archive instead of delete" path) never call `countFundsOfWallet`. The delete path does (`:221`). `watchTotalAssets` (`repository.dart:245`) drops archived wallets, but `watchTotalInFunds` (`:380`) still subtracts every non-archived fund.
- **Input:** Wallet A holds 5,000,000, including fund "Tết" with 2,000,000. Wallet B holds 3,000,000. Spendable = 8M − 2M = **6M**. After archiving A: total = 3M, but funds are still 2M, so spendable = **1M**. The fund money is subtracted from wallet B, which never held it. Free money and every budget cash cap drop with it.
- **Fix:** block archiving while `countFundsOfWallet > 0`, using the same message as delete. Alternatively, make `watchTotalInFunds` join `wallets` and skip archived ones. Blocking is simpler and matches the delete rule.
- **Test:** `wallet_delete_test.dart`: archive a fund-holding wallet, then assert spendable or that archiving is refused.

### B2. `watchSpendableAssets` misses fund changes
- **Where:** `repository.dart:418-424`. The stream re-emits only when `watchTotalAssets` emits, which reads `{wallets, transactions}`. Funds and debts are fetched with `.first` inside `asyncMap`.
- **Input:** `archiveFund(id, archived: true)` on a fund with saved money changes only the `funds` table. `spendableAssetsProvider`, the free-money figure and the budget caps keep the old value until an unrelated wallet or transaction write. No UI calls `archiveFund` today, so this is latent. Any future change that touches only `funds` will hit it.
- **Fix:** one SQL query whose `readsFrom` is `{wallets, transactions, funds}`, built from the existing expressions. This also removes the triple query per emission.
- **Test gap:** all 9 tests that touch spendable use `.first`, so no test checks re-emission. Add a test that listens to the stream, archives a fund and expects a second value.

### B3. Backup "merge" keeps `groupId`, so two imports fuse split-bill groups
- **Where:** `backup_service.dart` import, `groupId: Value(row['groupId'] as String?)`.
- **Input:** import the same backup twice in merge mode (or two backups that overlap). The split-bill pair from file 1 and its copy from file 2 share one UUID. Deleting either copy shows "nhóm 4 giao dịch" and soft-deletes all four (`softDeleteGroup`).
- **Fix:** map each distinct `groupId` in the file to a new `Uuid().v4()` per import, the same way ids are remapped.
- **Test:** `backup_test.dart`: merge the same file twice, then `countInGroup` = 2 for each.

### B4. Import is a second write path that skips `addTransaction`'s guards
- **Where:** `backup_service.dart` transaction loop. It never checks `amount > 0`. It also doesn't call `_checkPaidByOther`, doesn't check the bill total against the amount, and `TxKindX.fromId` throws `StateError` on an unknown kind.
- **Input:** a file with `"amount": -50000` (hand-edited or corrupt) is stored as a negative amount. That breaks the "amount always positive" invariant, and the wallet balance moves the wrong way. `"kind": "gift"` shows a raw `Bad state: No element` instead of a `BackupException`.
- **Fix:** validate each row before the DB transaction: amount > 0, a known kind, and paid-by-other rows without wallets. Throw `BackupException` with the row index. Reuse the same check functions as the repository: move `_checkPaidByOther` / `_checkBill` into `lib/core/domain/tx_rules.dart`, which Phase 2 extracts anyway.
- **Test:** negative amount, unknown kind, and a mismatched bill each raise `BackupException`, and the DB stays untouched.

### B5. Day-dependent widgets read `DateTime.now()` instead of `todayProvider`
- **Where:** `dashboard_screen.dart:223` (month label) and `:268` (`_dailyAverage`), `budget_screen.dart:106`, `stats_screen.dart:82`, `providers.dart:93` (`selectedMonthProvider` seeded from `currentMonthKey()`).
- **Input:** the app sits in the background from the 10th to the 11th, with no new transactions. `_MonthSummaryCard` only watches `currentMonthTotalsProvider`, so it doesn't rebuild, and "Chi/ngày" still divides by 10. CLAUDE.md forbids exactly this.
- **Fix:** `ref.watch(todayProvider)` in those widgets, and pass `now:` to `daysElapsedIn`. `selectedMonthProvider` is a user selection, so seeding it once is acceptable. Write down that decision rather than changing it.

### B6 (low likelihood). Saving an edited transaction before its bill loads deletes the bill
- **Where:** `tx_editor_screen.dart:131` starts `_loadBill` asynchronously. Until it finishes, `_bill.enabled` is false, so `_save` sends `bill: []`, which means "remove the bill".
- **Fix:** while loading, send `bill: null` ("keep"), e.g. a `_billLoaded` flag. It can go into the Phase 2 rules extraction.

---

## 2. SOLID review (lib/)

**Verdict:** the domain layer (`tx_kind.dart`, `fund_delta.dart`, `bill.dart`, `free_money.dart`) is healthy. The problems are two god files (`repository.dart`, `tx_editor_screen.dart`) and invariants copied by hand into several places.

### Invariants (CLAUDE.md)
- ✅ Amounts are `int`, and no `double` money. `ratio` doubles are display-only.
- ✅ One balance formula, but **its SQL text is copied 3 times**: `repository.dart:218-224`, `:247-254`, `:266-272`. If one copy changes and the others don't, the totals disagree. Extract `_balanceExpr` the way `_fundSavedExpr` already is.
- ✅ Sign comes only from `kind.debtDelta` / `fundDeltaOf` in `addTransaction` and `updateTransaction`. ❌ The import path builds `TransactionsCompanion` itself (B4).
- ✅ No SQL in `lib/features/`, ❌ except `backup_service.dart`, which uses `db.select` / `db.delete` directly (19 calls). That's acceptable for a service, but it belongs in `lib/core/db/backup_dao.dart` or behind the repository.
- ✅ Foreign keys are on, and day/month keys are computed in Dart.
- ❌ "Stats only count income/expense": `TxKind.countsInStats` is **used nowhere in lib/**. Instead, `'expense'` / `'income'` literals are hardcoded in 6 SQL strings (`repository.dart:1351, 1427, 1469, 1476, 1535, 1570`).
- ❌ "Today" via `todayProvider`: see B5.

### Findings
| # | Principle | Where | Problem | Suggested change | Worth it? |
|---|---|---|---|---|---|
| 1 | S | `repository.dart:200-1644` | One class covers wallets, funds, templates, categories, people, debts, transactions, bills, stats and budgets. Any feature edits this 2k-line file, and reviews mix domains. | Phase 1 `part` split per domain, keeping the public API (see §3). | Yes |
| 2 | S | `repository.dart:1646-1972` | `BudgetProgress`, `BudgetPace`, `capBudgetsByCash` and `kRecoveryCut` are pure domain logic (330 lines) inside the DB file. | Move to `lib/core/domain/budget_progress.dart` and re-export it. | Yes |
| 3 | DRY/S | `repository.dart:881-895, 987-998, 1291-1303, 1416-1427` | The TxView `SELECT … LEFT JOIN` is written out 4 times. A new column needs 4 edits, and a missed one breaks `_rowToTxView` at runtime. | `static const _txViewSelect` plus a `WHERE`/`ORDER` suffix. | Yes |
| 4 | O | `tx_editor_screen.dart:99,107,157,217,223,281,467,555,557,603,645` | 11 `_kind == TxKind.x` checks, although the class doc says "adding a kind needs no change here". Split, bill, fund and template only work for `expense`. | Add `TxKind` flags `canSplit`, `canHaveBill`, `canUseFund`, `categoryFlow` (and use them in `_rowToTxView:934` too). | Yes |
| 5 | S | `tx_editor_screen.dart:69-709` | The 640-line State class mixes form rules (`_canX`, `_changeKind`, `_validateSelection`), actions (`_save`, `_saveSplitBill`, `_confirmDelete`, `_saveAsTemplate`) and layout. None of the rules can be unit-tested without pumping the widget. | Phase 2: `TxFormRules` (pure, tested) and `TxEditorActions`. | Yes |
| 6 | Stringly-typed | category `flow` `'income'/'expense'` (19 places) | Typos compile, and `watchCategoryTotals(flow: 'incom')` silently returns expenses. | `enum CategoryFlow { expense, income }` with a Drift `textEnum`. Needs a migration/codegen, so do it **later**. | Later |
| 7 | I | `CashLimitNote`, `PaceMarkerBar` live in `budget_screen.dart` but are imported by `stats_screen` and `home/budget_today_section` | Features import a screen file to get a widget, which creates cross-feature coupling. | Move them to `features/budgets/widgets/pace_widgets.dart`. | Yes (pure move) |
| 8 | D | `backup_service.dart` | Builds rows and runs the import SQL itself. It is a second owner of the "how a transaction is written" rules (B4). | Split by direction (§3), and route row validation through shared domain checks. | Yes |
| 9 | S | `split_bill_section.dart:11-98` | `SplitState` (share maths and validation) is pure logic sitting with widgets and is **untested**. | Move it to `split_state.dart` and add tests first. | Yes |
| 10 | Test design | tests | `makeProgress()` / `budget()` builders are copied in 3 files. `newWallet`/`newCategory`/`newPerson` helpers and the in-memory DB `setUp` are copied in 15 files. | `test/helpers/db.dart` and `test/helpers/builders.dart`. | Yes |

### Leave as is
- **No abstract `IRepository`.** Tests use a real in-memory Drift DB, which is better than a mock.
- **`part` files plus extensions on `Repository`** instead of 10 injected DAO classes. Consumers stay unchanged, and the private helpers (`_now`, `_rowToTxView`, `_fundDeltaFor`) stay shared. DAO classes can come later if a real second consumer appears.
- **`TxView.signedAmount` / `title` branching on `TxKind.transfer`.** This is display logic, not balance logic, and it is tested (`paid_by_other_test.dart:166`).
- **`watchDebts`' `includeSettled ? 'WHERE p.is_archived = 0' : ''`** looks inverted but is deliberate: hidden people with open debts must still show. Add a one-line comment.
- **`lib/core/widgets.dart` (398 lines)** is just under the target and every widget in it is independent.
- **`DateTime.now()` in `_now()`, editor `initState`, backup filenames:** these are write timestamps and defaults, not "today" logic.

---

## 3. Phase 1: pure moves (no logic change)

One file per commit, message `refactor: move X to Y (no behaviour change)`. Check each with `git diff -M --stat`, then analyze and test. All `customSelect` strings, `readsFrom` sets and provider names stay byte-identical.

### 3.1 `repository.dart` (1989 lines), mechanism A (`part` + extensions)

Keep `class Repository` in `repository.dart`. Each section moves into `extension XQueries on Repository` inside a `part` file. Callers still write `repo.balanceOf(...)`.

Traps to handle:
- Static members aren't in scope unqualified inside an extension. Write `Repository._fundSavedExpr` / `Repository._billCountExpr` in the moved code. This is the only allowed textual edit.
- View models and `BudgetProgress` move to **separate libraries** (not parts). `repository.dart` then adds `export 'repository_models.dart'; export '../domain/budget_progress.dart';`, so the 40+ importers don't change.
- No importer uses `show`/`hide` on `repository.dart` (checked), so the extensions stay visible everywhere.

| Step | New file | Content (current lines) | ~Lines |
|---|---|---|---|
| 1 | `core/db/repository_models.dart` | `WalletWithBalance`, `DebtSummary`, `TxView`, `FundProgress`, `TemplateView`, `MonthTotals`, `CategoryTotal` (11-195, 1974-1989) | 215 |
| 2 | `core/domain/budget_progress.dart` | `BudgetPace`, `BudgetProgress`, `kRecoveryCut`, `capBudgetsByCash` (1646-1972) | 330 |
| 3 | `core/db/repository_wallets.dart` | Ví (204-341) | 140 |
| 4 | `core/db/repository_funds.dart` | Quỹ minus `_fundSavedExpr`/`_fundDeltaFor` (376-567) | 195 |
| 5 | `core/db/repository_templates.dart` | Mẫu chi tiêu (569-700) | 135 |
| 6 | `core/db/repository_catalog.dart` | Danh mục and Người (702-784) | 85 |
| 7 | `core/db/repository_debts.dart` | Sổ nợ (786-833) | 50 |
| 8 | `core/db/repository_transactions.dart` | 835-1340 minus `_rowToTxView`/`_lightWallet`/bill helpers | 410 |
| 9 | `core/db/repository_bills.dart` | `_checkBill`, `_writeBill`, `watchBill` (1095-1136) | 45 |
| 10 | `core/db/repository_stats.dart` | Thống kê (1342-1442) | 100 |
| 11 | `core/db/repository_budgets.dart` | Ngân sách (1444-1639) | 200 |
| — | `core/db/repository.dart` (remains) | class, `db`, `_now`, `_uuid`, `_fundSavedExpr`, `_fundDeltaFor`, `_billCountExpr`, `_rowToTxView`, `_lightWallet`, `_checkPaidByOther`, `part`/`export` lines | 150 |

### 3.2 Screens and services, mechanism C/D (private widget becomes a public widget file)

| File | Moves out | Remains |
|---|---|---|
| `tx_editor_screen.dart` 1049 | `widgets/kind_selector.dart` (`_KindSelector`, `_KindChip`, ~85), `widgets/wallet_dropdown.dart` (~60), `widgets/category_picker.dart` (~65), `widgets/fund_picker.dart` (~60), `widgets/person_picker.dart` (~67) | ~710 (Phase 2 continues) |
| `budget_screen.dart` 900 | `widgets/pace_widgets.dart` (`PaceMarkerBar`, `CashLimitNote`, `BudgetPaceRow`, ~270), `budget_card.dart` (`_BudgetCard`, `_PaceBadge`, `_StatusChip`, ~180), `budget_editor_sheet.dart` (~195) | ~260 |
| `stats_screen.dart` 886 | `month_comparison.dart` (`_MonthComparison`…`_LegendDot`, ~290), `category_breakdown.dart` (~175, with `_categoryTotalsProvider`), `budget_summary.dart` (~140), `top_expenses.dart` (~65, with `_topExpensesProvider`) | ~225 |
| `fund_screen.dart` 862 | `fund_transfer_sheet.dart` (~258), `fund_editor_sheet.dart` (~306) | ~300 |
| `category_detail_screen.dart` 705 | `daily_chart_card.dart` (`_ChartCard`, swatch, ~210), `daily_chart_painter.dart` (~240), `daily_totals.dart` (`dailyTotals`, pure, ~15) | ~245 |
| `backup_service.dart` 594 | `backup_models.dart` (`BackupStats`, `ImportMode`, `ImportResult`, `BackupException`, ~70), `backup_export.dart` (`buildJson` + `_xToMap`, ~170), `backup_csv.dart` (~70), `backup_import.dart` (`import` + `_decodeAndValidate`, ~300) | facade ~60 (`BackupService` delegates) |
| `dashboard_screen.dart` 560 | `quick_action_sheet.dart` (~70), `wallets_section.dart` (~80), `recent_section.dart` (~100) | ~310 |
| `template_screen.dart` 495 | `template_editor_sheet.dart` (~250) | ~245 |
| `split_bill_section.dart` 419 | `split_state.dart` (`SplitMode`, `SplitState`, ~90). **Write characterization tests first** (finding 9). | ~330 |

Order: repository first (largest risk, best covered by tests), then `tx_editor_screen` (has widget tests), budget, stats, funds, category_detail, backup, dashboard, templates, split.

---

## 4. Phase 2: extractions (tests first, each a labelled `refactor:` change)

1. **Shared SQL fragments** in the repository: `_balanceExpr` (finding 3 under Invariants) and `_txViewSelect` (finding 3). This cuts about 90 lines and leaves one place to change. The existing balance and transaction tests pin the behaviour. Diff the SQL text before and after.
2. **`TxKind` editor flags** (finding 4): `canSplit`, `canHaveBill`, `canUseFund`, `categoryFlow`. First extend `tx_kind_test.dart` with a truth table for all 8 kinds, then replace the 11 comparisons.
3. **`TxFormRules`** → `lib/features/transactions/tx_form_rules.dart` (~180). Pure functions over an immutable `TxDraft` (`kind`, wallet ids, category, person, fund, `paidByOther`, `split.enabled`, `bill.enabled`, `isEditing`):
   - `canSplit`, `canBill`, `canPayByOther`, `canSaveAsTemplate`
   - `afterKindChange(next)`: today's `_changeKind` clearing, quirks included
   - `validateSelection()`
   - `resolvedIds()`: the wallet, person and fund nulling done in `_save`

   Test file `tx_form_rules_test.dart`, written against the current behaviour first.
4. **`TxEditorActions`** → `tx_editor_actions.dart` (~150): `save`, `saveSplit`, `deleteWithGroup`, `saveAsTemplate`. Each takes `Repository` + `TxDraft` and returns a result (ids and a message key). Snackbars and `Navigator` stay in the screen. B6 is fixed here, in a separate `fix:` commit.
5. **Editor sections**: `_paidByOtherSection` becomes `paid_by_other_section.dart`, `_impactNote` becomes `impact_note_section.dart`. Keep the widget order, so focus and dropdown state don't reset. The screen ends at **~330 lines**.
6. **Shared write rules**: move `_checkPaidByOther`, `_checkBill` and the debt/fund delta derivation into `lib/core/domain/tx_rules.dart`. Both the repository and the backup import call them. This is the groundwork for the B4 fix.
7. **`watchSpendableAssets` as a single query**: groundwork for the B2 fix. Pin the current values with the existing tests first.
8. **Test helpers** (finding 10): `test/helpers/db.dart` (`openTestRepo()`), `test/helpers/builders.dart` (`makeProgress`, `newWallet`, `newCategory`, `newPerson`). Migrate one test file per commit, and keep the test count at exactly 304.

---

## 5. Stale code and stale tests

| Item | Evidence | Action |
|---|---|---|
| `Repository.countTransactionsOfFund` | 0 uses in `lib/` or `test/` | Delete |
| `Repository.transactionsInGroup` | 0 uses | Delete |
| `Repository.watchTransactionById` | only called by `getTransaction` | Make `getTransaction` use `_txViewSelect … WHERE t.id = ?` with `.getSingleOrNull()`, then delete the stream |
| `Repository.savedInFund` | used only in `fund_test.dart` (2) | Delete. Tests read `watchFunds().first` |
| `Repository.archiveFund` | only `fund_test.dart:362`, no UI. It is also the B2 trigger | **Decision needed:** add an "Archive fund" UI action (and fix B2), or delete it with its test. |
| `totalAssetsProvider` | 0 uses outside `providers.dart` | Delete |
| `TxKind.countsInStats` | used only in `tx_kind_test.dart`. SQL hardcodes the kinds | Use it to build the `kind IN (...)` lists in the stats SQL, or delete flag and test. Prefer using it. |
| `BudgetPaceRow` public | used only in `budget_screen.dart` | Make it private after the move, or keep it public in `pace_widgets.dart` |
| `test/budget_cash_test.dart` tests `dailyTotals` | that function belongs to `category_detail_screen` | Move those tests to `test/daily_totals_test.dart` |
| `test/cursor_test.dart` | tests `ThousandsFormatter`, so the name says nothing | Rename to `thousands_formatter_test.dart` |
| `recurring_templates` table, `addTransaction(recurringId:)` | unused feature ("Chưa làm" in CLAUDE.md) | Leave. It is documented as planned. |
| `CLAUDE.md` "304 test" | correct today. It will drift after these changes | Update the count in the final commit |
| `.gitignore` adds `.claude/` (uncommitted) | this would also ignore the project skills `refactor-split` / `solid-check` | **Check:** narrow it to `.claude/settings.local.json` if the skills are meant to be shared |

### Missing tests (add when touching the code)
- Stream re-emission for `watchSpendableAssets` (B2) and for one `readsFrom` set per section. A dropped table in `readsFrom` currently fails silently.
- `SplitState` (equal split rounding, custom-share validation, `myShareFor`).
- Backup: merge twice (B3), invalid rows (B4), `recurringId` not exported (document it).
- Widget tests for the budget, stats and dashboard screens: none exist. At least one smoke `pumpWidget` per screen before Phase 1 moves its widgets.

---

## 6. End state

| File | ~Lines | Note |
|---|---|---|
| `core/db/repository.dart` | 150 | facade + shared helpers |
| `core/db/repository_transactions.dart` | **330** | after `_txViewSelect` (410 after Phase 1 only) |
| `core/domain/budget_progress.dart` | **330** | over 300 per class: `BudgetProgress` is one cohesive pace model whose getters build on each other. Splitting it would scatter one formula. Justified. |
| `core/db/repository_models.dart` | 215 | |
| `core/db/repository_budgets.dart` | 200 | |
| `core/db/repository_funds.dart` | 175 | after the B2 single query |
| other `repository_*.dart` | 45–140 | |
| `transactions/tx_editor_screen.dart` | 330 | wiring only |
| `transactions/tx_form_rules.dart` | 180 | |
| `transactions/tx_editor_actions.dart` | 150 | |
| `transactions/split_bill_section.dart` | 330 | |
| `backup/backup_import.dart` | **~320** | including B4 row validation. One transaction keeps the id maps local. Justified. |
| `funds/fund_editor_sheet.dart` and the other sheets | ≤ 310 | |
| `stats/month_comparison.dart` | 290 | |
| `home/dashboard_screen.dart` | 310 | |
| `core/widgets.dart` | 398 | unchanged |

**Largest file after both phases: ~330 lines.** No file exceeds the 400 target. Two files exceed 300 per class, with the reasons stated above.

## 7. Later (real behaviour or API changes, not part of this refactor)
- `enum CategoryFlow` replacing the `'income'/'expense'` strings (needs codegen and a migration).
- Merge-mode import creates duplicate categories and people (by design today). Consider matching by name.
- `ImportResult.stats` counts file rows, not inserted rows (skipped funds and budgets are still counted).
- `backup_service` SQL moved into `core/db/` (a `BackupDao`).
- Budget `spent` counts expenses paid from a fund. Free money excludes them (`watchSpentOutsideBudgetsOnDay`), but `watchBudgets` doesn't. Confirm whether that is intended and document it in CLAUDE.md.
- Fund editor lets you change `walletId`. Past `fund_delta` rows were computed against the old wallet. Confirm the semantics.

## 8. Order of work

1. Commit or drop the `.gitignore` change. Decide on `archiveFund` (§5).
2. Fix B1–B5, each with its failing test first (5 `fix:` commits).
3. Add the missing smoke and characterization tests (one `test:` commit).
4. Phase 1 moves (§3), about 30 commits. Test count unchanged.
5. Phase 2 extractions (§4), about 8 commits. The test count only grows.
6. Remove stale code (§5), then update CLAUDE.md (structure section, test count).
