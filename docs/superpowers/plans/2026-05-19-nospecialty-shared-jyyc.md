# Nospecialty Shared JYYC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the 普药经营预测 procedure with the document's unit base price rule and extend the shared ticket/cost/period-fee/profit calculations to 新特药 rows, then write those shared results back to existing 新特药 records.

**Architecture:** Keep one shared temporary calculation pipeline inside `Cost_Data_Cost_Sales_Nospecialty_Drugs_Jyyc`. 普药 rows are still inserted as new records, while 新特药 rows are loaded from existing `mis_auto_jyycmx`, processed through the shared stages only, and updated back into place at the end.

**Tech Stack:** PostgreSQL PL/pgSQL, temp tables, `mis_auto_ptpcr`, `mis_auto_jyycmx`, `mis_auto_ibslt`

---

### Task 1: Correct Unit Base Price Matching

**Files:**
- Modify: `C:\Users\15130\Desktop\当前任务\5.19\普药\Cost_Data_Cost_Sales_Nospecialty_Drugs_Jyyc.txt`

- [ ] **Step 1: Keep the previous-month source and customer-dimension switch**
- [ ] **Step 2: Confirm only 普药 source rows use this base-price lookup**
- [ ] **Step 3: Preserve existing row-number winner selection**

### Task 2: Extend Shared Calculation Scope

**Files:**
- Modify: `C:\Users\15130\Desktop\当前任务\5.19\普药\Cost_Data_Cost_Sales_Nospecialty_Drugs_Jyyc.txt`

- [ ] **Step 1: Load 新特药 row ids from existing `public.mis_auto_jyycmx`**
- [ ] **Step 2: Insert 新特药 rows into the temp working table with preserved precomputed front fields**
- [ ] **Step 3: Change current-discount and cross-period discount helper tables from 普药-only scope to shared scope**
- [ ] **Step 4: Keep 新特药 `例行费用/销售费用` values from its own process while still computing shared cost and other fee fields**

### Task 3: Split Final Persistence

**Files:**
- Modify: `C:\Users\15130\Desktop\当前任务\5.19\普药\Cost_Data_Cost_Sales_Nospecialty_Drugs_Jyyc.txt`

- [ ] **Step 1: Materialize final shared results into a reusable temp result set**
- [ ] **Step 2: Insert only `普药非新特药` rows into `public.mis_auto_jyycmx`**
- [ ] **Step 3: Update existing `新特药` rows with shared fields only**

### Task 4: Validate With DB Queries

**Files:**
- Modify: `C:\Users\15130\Desktop\当前任务\5.19\普药\Cost_Data_Cost_Sales_Nospecialty_Drugs_Jyyc.txt`

- [ ] **Step 1: Run pre-change select-style checks for unit base price and 新特药 shared scope**
- [ ] **Step 2: Run static SQL structure checks after patching**
- [ ] **Step 3: Run post-change select-style checks that mirror the modified temp logic**
