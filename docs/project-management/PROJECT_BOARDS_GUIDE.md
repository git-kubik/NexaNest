---
title: "GitHub Projects Configuration Guide"
description: "Step-by-step instructions for setting up GitHub Projects for NexaNest cloud services delivery team"
authors:
  - "Project Management Team"
  - "DevOps Team"
datetime: "2025-11-06 14:50:00"
status: "approved"
tags:
  - "project-management"
  - "github-projects"
  - "workflow"
  - "automation"
  - "configuration"
category: "business"
audience: "manager"
complexity: "intermediate"
technology_stack:
  - "GitHub Projects"
  - "GitHub Actions"
business_value: "high"
---

# GitHub Projects Configuration Guide

## Overview

This guide provides step-by-step instructions for setting up GitHub Projects for the NexaNest cloud services delivery team. We'll configure automated project boards with custom views for different stakeholders.

## Project Structure

### 1. Main Delivery Board
Primary board for tracking all active work across services.

### 2. Component Boards
Specialized boards for each service team:
- Frontend Board
- Backend Services Board  
- Infrastructure Board
- AI/ML Board

### 3. Executive Dashboard
High-level view for stakeholders and leadership.

## Setup Instructions

### Step 1: Create the Main Project

1. Navigate to the Projects tab in your repository
2. Click "New project"
3. Select "Board" template
4. Name it "NexaNest Delivery Board"

### Step 2: Configure Fields

Add these custom fields to your project:

```yaml
fields:
  - name: "Sprint"
    type: iteration
    configuration:
      duration: 2 weeks
      start_date: "Monday"
      
  - name: "Story Points"
    type: number
    
  - name: "Team"
    type: single_select
    options:
      - Frontend
      - Auth Service
      - Portfolio Service
      - Market Data
      - AI/ML
      - Infrastructure
      - QA
      
  - name: "Release"
    type: single_select
    options:
      - v1.0
      - v1.1
      - v2.0
      - Backlog
      
  - name: "Risk Level"
    type: single_select
    options:
      - Low
      - Medium
      - High
      - Critical
      
  - name: "Business Value"
    type: single_select
    options:
      - Low
      - Medium
      - High
      - Critical
```

### Step 3: Configure Columns

Set up these columns with automation:

#### Backlog
- **Description**: Items pending prioritization
- **Automation**: 
  - When: Issue created
  - Add to project with status "Backlog"

#### Ready
- **Description**: Prioritized and ready to start
- **Automation**:
  - When: Label "status: ready" added
  - Move to "Ready" column

#### In Progress
- **Description**: Active development
- **Limit**: 3 items per developer
- **Automation**:
  - When: Label "status: in-progress" added
  - Move to "In Progress" column
  - When: Assignee added
  - Move to "In Progress" column

#### In Review
- **Description**: Code review phase
- **Automation**:
  - When: PR opened
  - Move to "In Review" column
  - When: Label "status: review" added
  - Move to "In Review" column

#### Testing
- **Description**: QA verification
- **Automation**:
  - When: Label "status: testing" added
  - Move to "Testing" column

#### Done
- **Description**: Completed items
- **Automation**:
  - When: Issue closed
  - Move to "Done" column
  - When: Label "status: done" added
  - Move to "Done" column

### Step 4: Create Views

#### 1. Sprint Board (Default View)
```yaml
view: Board
grouping: Status
filtering:
  - Sprint = @current or Sprint = @next
sorting: Priority (High to Low)
```

#### 2. Team Workload View
```yaml
view: Table
columns:
  - Title
  - Assignee
  - Team
  - Status
  - Story Points
  - Sprint
grouping: Team, then Assignee
filtering:
  - Sprint = @current
  - Status != Done
```

#### 3. Risk Management View
```yaml
view: Board
grouping: Risk Level
filtering:
  - Status != Done
  - Risk Level != Low
sorting: Priority (High to Low)
display:
  - Title
  - Risk Level
  - Team
  - Assignee
  - Due Date
```

#### 4. Timeline View
```yaml
view: Roadmap
date_field: Sprint
grouping: Team
filtering:
  - Status != Done
display:
  - Milestones
  - Dependencies
```

#### 5. Executive Dashboard
```yaml
view: Table
columns:
  - Title
  - Business Value
  - Status
  - Progress %
  - Risk Level
  - Release
grouping: Release, then Business Value
filtering:
  - Business Value = High or Business Value = Critical
summary:
  - Count by Status
  - Sum of Story Points by Team
```

#### 6. Blocked Items View
```yaml
view: Table
filtering:
  - Label contains "blocked"
  - Status != Done
columns:
  - Title
  - Blocked Since (calculated)
  - Assignee
  - Blocker Description
  - Team
sorting: Blocked Since (Oldest First)
```

## Automation Workflows

### 1. Sprint Planning Automation
```yaml
name: Sprint Planning
trigger: Sprint field changes to @current
actions:
  - Add label "sprint: current"
  - Remove label "sprint: next"
  - Post comment with sprint goals
```

### 2. Stale Item Detection
```yaml
name: Stale Item Detection
trigger: Daily at 9 AM
condition: 
  - Status = "In Progress"
  - No activity for 3 days
actions:
  - Add label "needs: update"
  - Post comment mentioning assignee
```

### 3. Auto-assignment
```yaml
name: Team Auto-assignment
trigger: Label added
conditions:
  - Label matches "component:*"
actions:
  - Set Team field based on component
  - Suggest assignees from team roster
```

### 4. Scope Change Tracking
```yaml
name: Scope Change Handler
trigger: Label "scope-change" added
actions:
  - Add to "Scope Changes" project
  - Set Risk Level to "High"
  - Notify project manager
  - Create linked approval issue
```

## Project Insights Configuration

### Velocity Chart
- X-axis: Sprint
- Y-axis: Story Points Completed
- Group by: Team

### Burndown Chart
- Scope: Current Sprint
- Ideal line: Based on story points
- Actual line: Completed story points

### Cycle Time
- Measure: Ready → Done
- Group by: Issue Type
- Display: Average, p50, p95

### Custom Reports

#### 1. Sprint Health Report
```sql
SELECT 
  sprint,
  COUNT(CASE WHEN status = 'Done' THEN 1 END) as completed,
  COUNT(CASE WHEN status != 'Done' THEN 1 END) as remaining,
  SUM(story_points) as total_points,
  AVG(CASE WHEN status = 'Done' THEN cycle_time END) as avg_cycle_time
FROM issues
WHERE sprint = @current
GROUP BY sprint
```

#### 2. Team Capacity Report
```sql
SELECT 
  team,
  assignee,
  COUNT(*) as assigned_items,
  SUM(story_points) as total_points,
  COUNT(CASE WHEN priority = 'Critical' THEN 1 END) as critical_items
FROM issues
WHERE status NOT IN ('Done', 'Closed')
GROUP BY team, assignee
ORDER BY total_points DESC
```

## Integration Points

### Slack Integration
```yaml
notifications:
  - event: Item moved to Blocked
    channel: "#nexanest-blockers"
    
  - event: Critical priority added
    channel: "#nexanest-incidents"
    
  - event: Sprint completed
    channel: "#nexanest-general"
    template: Sprint summary with metrics
```

### GitHub Actions Integration
```yaml
on:
  project_card:
    types: [moved]
    
jobs:
  update_status:
    if: github.event.project_card.column_name == 'Testing'
    steps:
      - name: Trigger test suite
        run: |
          echo "Running tests for issue #${{ github.event.issue.number }}"
```

## Best Practices

### 1. Daily Workflow
- Review "Blocked Items" view each morning
- Update item status throughout the day
- Check WIP limits before starting new work

### 2. Sprint Ceremonies
- **Planning**: Use "Backlog" view grouped by Business Value
- **Daily Standup**: Use "Sprint Board" filtered to assignee
- **Review**: Use "Done" items from current sprint
- **Retrospective**: Review velocity and cycle time charts

### 3. Stakeholder Updates
- Share "Executive Dashboard" view link
- Set up weekly automated reports
- Maintain Risk Management view accuracy

### 4. Maintenance
- Archive completed sprints monthly
- Review and update automation rules quarterly
- Clean up stale custom fields
- Audit user permissions

## Troubleshooting

### Common Issues

1. **Items not moving automatically**
   - Check label spelling
   - Verify automation is enabled
   - Check permissions

2. **Duplicate items appearing**
   - Check for multiple project associations
   - Review automation rules for conflicts

3. **Performance issues**
   - Limit view complexity
   - Archive old items
   - Reduce custom field count

## Migration from Other Tools

### From Jira
```bash
# Export Jira data
jira-export --project NEXA --format csv

# Import to GitHub
gh project item-create --project "NexaNest Delivery Board" --field-csv jira-export.csv
```

### From Trello
Use GitHub's built-in Trello importer in Project settings.

## Metrics and KPIs

Track these metrics weekly:

1. **Velocity Trend**: Story points per sprint
2. **Cycle Time**: Average days from start to done
3. **WIP Adherence**: % time within WIP limits
4. **Defect Rate**: Bugs per release
5. **Scope Creep**: % of unplanned work
6. **Team Utilization**: Assigned points vs capacity