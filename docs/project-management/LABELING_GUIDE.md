---
title: "GitHub Labeling Taxonomy Guide"
description: "Comprehensive labeling system for categorizing, prioritizing, and tracking work items in NexaNest project"
authors:
  - "Project Management Team"
datetime: "2025-11-06 14:45:00"
status: "approved"
tags:
  - "project-management"
  - "github"
  - "labels"
  - "taxonomy"
  - "workflow"
category: "business"
audience: "all"
complexity: "beginner"
technology_stack:
  - "GitHub"
business_value: "medium"
---

# GitHub Labeling Taxonomy Guide

## Overview

This guide defines the labeling system for the NexaNest project. Labels are used to categorize, prioritize, and track work items throughout their lifecycle.

## Label Categories

### 1. Priority Labels (Red Spectrum)
Used to indicate the urgency and importance of issues.

| Label | Color | Description | SLA |
|-------|-------|-------------|-----|
| `priority: critical` | #E00000 | Production blocking issues | < 4 hours |
| `priority: high` | #D73027 | High impact, address soon | < 2 days |
| `priority: medium` | #FC8D59 | Normal priority | < 1 sprint |
| `priority: low` | #FEE08B | Nice to have | As capacity allows |

### 2. Type Labels (Blue Spectrum)
Categorize the nature of the work.

| Label | Color | Description |
|-------|-------|-------------|
| `type: bug` | #0052CC | Defects and issues |
| `type: feature` | #0066FF | New functionality |
| `type: enhancement` | #4C9AFF | Improvements to existing features |
| `type: technical-debt` | #172B4D | Code quality improvements |
| `type: security` | #FF5630 | Security-related issues |
| `type: performance` | #00C7E6 | Performance optimizations |

### 3. Status Labels (Multiple Colors)
Track the current state of work items.

| Label | Color | Description | Next States |
|-------|-------|-------------|-------------|
| `status: triage` | #FFAB00 | Needs assessment | ready, wontfix |
| `status: ready` | #36B37E | Ready for work | in-progress |
| `status: in-progress` | #0052CC | Being worked on | blocked, review |
| `status: blocked` | #FF5630 | Waiting on dependency | in-progress |
| `status: review` | #6554C0 | In code review | testing, in-progress |
| `status: testing` | #00C7E6 | Being tested | done, in-progress |
| `status: done` | #00875A | Complete | - |

### 4. Component Labels (Purple Spectrum)
Identify which part of the system is affected.

| Label | Color | Service/Area |
|-------|-------|--------------|
| `component: frontend` | #6554C0 | React application |
| `component: auth-service` | #8777D9 | Authentication |
| `component: portfolio-service` | #998DD9 | Portfolio management |
| `component: market-data` | #B3A7E5 | Market data integration |
| `component: ai-ml` | #C7B9FF | AI/ML services |
| `component: analytics` | #DFD8FF | Analytics engine |
| `component: infrastructure` | #403294 | DevOps/Infrastructure |
| `component: database` | #5243AA | Database layer |

### 5. Effort Labels (Orange Spectrum)
Estimate the size of work.

| Label | Color | Time Estimate | Story Points |
|-------|-------|---------------|--------------|
| `effort: XS` | #FFF0B3 | < 2 hours | 1 |
| `effort: S` | #FFD93D | 2-4 hours | 2-3 |
| `effort: M` | #FFAB00 | 1-2 days | 5 |
| `effort: L` | #FF8B00 | 3-5 days | 8 |
| `effort: XL` | #FF6C00 | > 5 days | 13+ |

### 6. Process Labels (Teal Spectrum)
Indicate additional requirements.

| Label | Color | Description |
|-------|-------|-------------|
| `needs: design` | #00B8D9 | Requires design input |
| `needs: discussion` | #00C7E6 | Needs team discussion |
| `needs: documentation` | #79E2F2 | Documentation updates needed |
| `needs: approval` | #B2F5EA | Stakeholder approval required |

### 7. Special Labels
For specific workflows and states.

| Label | Color | Use Case |
|-------|-------|----------|
| `good first issue` | #7057FF | Suitable for new contributors |
| `help wanted` | #008672 | Community help appreciated |
| `wontfix` | #FFFFFF | Will not be implemented |
| `duplicate` | #CFD3D7 | Duplicate of another issue |
| `invalid` | #E4E669 | Not a valid issue |

### 8. Scope Management Labels
For tracking scope changes.

| Label | Color | Description |
|-------|-------|-------------|
| `scope-change` | #FF5630 | Scope change request |
| `approval-required` | #FF5630 | Needs formal approval |
| `approved` | #00875A | Approved by stakeholders |
| `deferred` | #FFAB00 | Pushed to future release |

## Labeling Best Practices

### Required Labels
Every issue MUST have:
1. One **type** label
2. One **priority** label
3. One **status** label
4. At least one **component** label

### Label Combinations
Common label combinations and their meanings:

- `type: bug` + `priority: critical` + `env: production` = Production incident
- `type: feature` + `scope-change` + `approval-required` = New scope requiring approval
- `type: technical-debt` + `effort: XL` = Major refactoring needed
- `status: blocked` + `needs: discussion` = Blocked pending team decision

### Workflow Rules

1. **New Issues**: Start with `status: triage`
2. **After Triage**: Add priority, effort, and component labels
3. **Ready for Work**: Change to `status: ready`
4. **Work Begins**: Update to `status: in-progress`
5. **Code Complete**: Move to `status: review`
6. **After Review**: Progress to `status: testing`
7. **Verified**: Mark as `status: done`

## Automation Rules

### Auto-labeling
- PRs automatically get `status: review`
- Issues from bug template get `type: bug` + `status: triage`
- Security issues get `priority: high` by default

### Label-triggered Actions
- `priority: critical` → Alerts team in Slack
- `status: blocked` → Notifies project manager
- `approved` → Moves to "Ready" column in project board

## Implementation

### Using GitHub CLI
```bash
# Apply all labels to a repository
gh label create -F .github/labels.yml

# Add labels to an issue
gh issue edit 123 --add-label "type: bug,priority: high,status: ready"

# Remove labels
gh issue edit 123 --remove-label "status: triage"
```

### Using github-label-sync
```bash
# Install
npm install -g github-label-sync

# Sync labels
github-label-sync --access-token YOUR_TOKEN --labels .github/labels.yml nexanest/nexanest
```

## Reporting

### Key Metrics by Labels
- **Velocity**: Sum of `effort:*` labels completed per sprint
- **Bug Rate**: Count of `type: bug` created vs resolved
- **Cycle Time**: Time from `status: ready` to `status: done`
- **Blocked Time**: Duration in `status: blocked`

### Dashboard Views
1. **Priority View**: Group by priority labels
2. **Component View**: Filter by component labels
3. **Status Board**: Kanban by status labels
4. **Effort Planning**: Sum effort labels by sprint

## Label Maintenance

### Monthly Review
- Remove unused labels
- Consolidate similar labels
- Update descriptions
- Review automation rules

### Label Governance
- Only team leads can create new labels
- Label changes require team discussion
- Document all label additions/changes
- Maintain consistency across repositories