# Reporting Views and Dashboards Guide

## Overview

This guide details the reporting structure for the NexaNest project management system, including dashboard configurations, custom views, and automated reports.

## Dashboard Architecture

### 1. Executive Dashboard
High-level view for C-suite and stakeholders.

**URL**: `https://github.com/orgs/nexanest/projects/1/views/executive`

**Key Metrics**:
- Overall project health score
- Budget vs. actual spend
- Release progress
- Risk heat map
- Team velocity trends

### 2. Delivery Dashboard
Operational view for delivery leads and project managers.

**URL**: `https://github.com/orgs/nexanest/projects/1/views/delivery`

**Key Metrics**:
- Sprint burndown
- Team capacity utilization
- Blocker resolution time
- Cycle time by component
- WIP limits adherence

### 3. Engineering Dashboard
Technical metrics for engineering teams.

**URL**: `https://github.com/orgs/nexanest/projects/1/views/engineering`

**Key Metrics**:
- Code review turnaround
- Test coverage trends
- Technical debt ratio
- Build success rate
- Deployment frequency

## GitHub Project Views Configuration

### Sprint Overview View
```yaml
name: Sprint Overview
type: Board
configuration:
  grouping:
    field: Status
    order: ["Backlog", "Ready", "In Progress", "Review", "Testing", "Done"]
  filtering:
    - field: Sprint
      operator: equals
      value: "@current"
  cards:
    display_fields:
      - Assignee
      - Story Points
      - Priority
      - Due Date
    color_by: Priority
  summary:
    show: true
    fields:
      - Story Points (sum)
      - Items (count by Status)
```

### Team Workload Matrix
```yaml
name: Team Workload
type: Table
configuration:
  columns:
    - Title
    - Assignee
    - Team
    - Story Points
    - Priority
    - Sprint
    - Status
  grouping:
    primary: Team
    secondary: Assignee
  filtering:
    - field: Status
      operator: not_in
      value: ["Done", "Closed"]
  sorting:
    - field: Priority
      direction: desc
    - field: Story Points
      direction: desc
  summary_row:
    - field: Story Points
      function: sum
      group_by: Team
```

### Risk Management Matrix
```yaml
name: Risk Matrix
type: Board
configuration:
  grouping:
    field: Risk Level
    order: ["Critical", "High", "Medium", "Low"]
  filtering:
    - field: Status
      operator: not_equals
      value: "Done"
  cards:
    display_fields:
      - Title
      - Owner
      - Impact
      - Mitigation Status
    color_scheme:
      Critical: "#E00000"
      High: "#FF6B6B"
      Medium: "#FFA500"
      Low: "#36B37E"
```

## Custom Reporting Queries

### 1. Velocity Report
```sql
WITH sprint_metrics AS (
  SELECT 
    sprint_number,
    sprint_start_date,
    COUNT(DISTINCT issue_id) as total_issues,
    SUM(CASE WHEN status = 'Done' THEN story_points ELSE 0 END) as completed_points,
    SUM(story_points) as committed_points,
    COUNT(DISTINCT CASE WHEN status = 'Done' THEN issue_id END) as completed_issues
  FROM issues
  WHERE sprint_number IS NOT NULL
  GROUP BY sprint_number, sprint_start_date
)
SELECT 
  sprint_number,
  sprint_start_date,
  completed_points,
  committed_points,
  ROUND(completed_points::numeric / NULLIF(committed_points, 0) * 100, 2) as completion_rate,
  completed_points - LAG(completed_points) OVER (ORDER BY sprint_start_date) as velocity_change
FROM sprint_metrics
ORDER BY sprint_start_date DESC
LIMIT 10;
```

### 2. Cycle Time Analysis
```sql
WITH cycle_times AS (
  SELECT 
    i.id,
    i.title,
    i.component,
    i.issue_type,
    e1.created_at as ready_time,
    e2.created_at as done_time,
    EXTRACT(EPOCH FROM (e2.created_at - e1.created_at))/86400 as cycle_days
  FROM issues i
  JOIN events e1 ON i.id = e1.issue_id AND e1.label = 'status: ready'
  JOIN events e2 ON i.id = e2.issue_id AND e2.label = 'status: done'
  WHERE e2.created_at > e1.created_at
)
SELECT 
  component,
  issue_type,
  COUNT(*) as issue_count,
  ROUND(AVG(cycle_days), 2) as avg_cycle_time,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cycle_days), 2) as median_cycle_time,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY cycle_days), 2) as p95_cycle_time
FROM cycle_times
GROUP BY component, issue_type
ORDER BY avg_cycle_time DESC;
```

### 3. Team Performance Metrics
```sql
SELECT 
  t.team_name,
  t.team_member,
  COUNT(DISTINCT i.id) as issues_completed,
  SUM(i.story_points) as points_delivered,
  AVG(i.cycle_time_days) as avg_cycle_time,
  COUNT(DISTINCT CASE WHEN i.priority = 'Critical' THEN i.id END) as critical_issues_resolved,
  ROUND(AVG(r.review_time_hours), 2) as avg_review_time
FROM team_members t
LEFT JOIN issues i ON t.team_member = i.assignee AND i.status = 'Done'
LEFT JOIN reviews r ON t.team_member = r.reviewer
WHERE i.closed_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY t.team_name, t.team_member
ORDER BY points_delivered DESC;
```

## Automated Reports

### Daily Standup Report
**Schedule**: Every weekday at 9:00 AM
**Recipients**: Team leads, Scrum masters

```yaml
template: |
  # Daily Standup Report - {{ date }}
  
  ## In Progress ({{ in_progress_count }})
  {{ #each in_progress_items }}
  - **#{{ number }}**: {{ title }} (@{{ assignee }})
    - Days in progress: {{ days_in_progress }}
    - Last update: {{ last_update }}
  {{ /each }}
  
  ## Blocked Items ({{ blocked_count }})
  {{ #each blocked_items }}
  - **#{{ number }}**: {{ title }} 
    - Blocked since: {{ blocked_date }}
    - Reason: {{ blocked_reason }}
    - Owner: @{{ assignee }}
  {{ /each }}
  
  ## Completed Yesterday ({{ completed_count }})
  {{ #each completed_items }}
  - **#{{ number }}**: {{ title }} ({{ story_points }} pts)
  {{ /each }}
  
  ## Today's Focus
  - Critical items: {{ critical_count }}
  - Items ready to start: {{ ready_count }}
```

### Weekly Sprint Report
**Schedule**: Every Friday at 4:00 PM
**Recipients**: All stakeholders

```yaml
sections:
  - name: Sprint Progress
    metrics:
      - Burndown chart
      - Velocity trend (last 4 sprints)
      - Completion percentage
      
  - name: Team Performance
    metrics:
      - Issues completed by team
      - Average cycle time
      - Review turnaround time
      
  - name: Quality Metrics
    metrics:
      - Bugs found vs fixed
      - Test coverage delta
      - Production incidents
      
  - name: Upcoming Work
    content:
      - Next sprint priorities
      - Dependencies and risks
      - Resource constraints
```

### Monthly Executive Summary
**Schedule**: First Monday of each month
**Recipients**: Executive team

```yaml
template: |
  # Executive Summary - {{ month }} {{ year }}
  
  ## Key Achievements
  - {{ features_delivered }} features delivered
  - {{ bugs_fixed }} bugs resolved
  - {{ performance_improvement }}% performance improvement
  
  ## Project Health
  - On-time delivery rate: {{ on_time_rate }}%
  - Budget utilization: {{ budget_used }}%
  - Team satisfaction: {{ team_satisfaction }}/10
  
  ## Risk Summary
  {{ #each high_risks }}
  - **{{ title }}**: {{ mitigation_status }}
  {{ /each }}
  
  ## Next Month Focus
  - {{ next_month_priorities }}
```

## Dashboard Implementation

### Using GitHub Insights API
```javascript
// fetch-metrics.js
const { Octokit } = require("@octokit/rest");

async function fetchProjectMetrics(projectId) {
  const octokit = new Octokit({
    auth: process.env.GITHUB_TOKEN,
  });

  // GraphQL query for project data
  const query = `
    query($projectId: ID!) {
      node(id: $projectId) {
        ... on ProjectV2 {
          items(first: 100) {
            nodes {
              id
              fieldValues(first: 20) {
                nodes {
                  ... on ProjectV2ItemFieldTextValue {
                    text
                    field { ... on ProjectV2Field { name } }
                  }
                  ... on ProjectV2ItemFieldNumberValue {
                    number
                    field { ... on ProjectV2Field { name } }
                  }
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field { ... on ProjectV2SingleSelectField { name } }
                  }
                }
              }
              content {
                ... on Issue {
                  number
                  title
                  state
                  labels(first: 10) {
                    nodes { name }
                  }
                  assignees(first: 5) {
                    nodes { login }
                  }
                }
              }
            }
          }
        }
      }
    }
  `;

  const result = await octokit.graphql(query, { projectId });
  return processMetrics(result);
}
```

### Grafana Dashboard Configuration
```json
{
  "dashboard": {
    "title": "NexaNest Project Metrics",
    "panels": [
      {
        "title": "Sprint Velocity",
        "type": "graph",
        "targets": [{
          "query": "SELECT sprint, sum(story_points) FROM completed_issues GROUP BY sprint"
        }]
      },
      {
        "title": "Cycle Time Distribution",
        "type": "heatmap",
        "targets": [{
          "query": "SELECT date_bin('1 day', completed_at), cycle_time_hours FROM issues"
        }]
      },
      {
        "title": "Team Workload",
        "type": "bargauge",
        "targets": [{
          "query": "SELECT assignee, count(*) as active_issues FROM issues WHERE status != 'Done' GROUP BY assignee"
        }]
      }
    ]
  }
}
```

## Metrics Definitions

### Velocity
**Definition**: Sum of story points completed in a sprint
**Target**: 80+ points per sprint
**Calculation**: `SUM(story_points) WHERE status = 'Done' AND sprint = current`

### Cycle Time
**Definition**: Time from 'Ready' to 'Done'
**Target**: < 5 days for medium issues
**Calculation**: `done_timestamp - ready_timestamp`

### Lead Time
**Definition**: Time from issue creation to 'Done'
**Target**: < 10 days
**Calculation**: `done_timestamp - created_timestamp`

### WIP Limit Adherence
**Definition**: Percentage of time WIP limits are respected
**Target**: > 90%
**Calculation**: `days_within_limit / total_days * 100`

### Defect Escape Rate
**Definition**: Bugs found in production vs. testing
**Target**: < 5%
**Calculation**: `production_bugs / (production_bugs + testing_bugs) * 100`

## Alert Configuration

### Critical Alerts
```yaml
alerts:
  - name: Critical Issue Unassigned
    condition: priority = 'critical' AND assignee IS NULL
    action: 
      - Slack notification to #incidents
      - Email to on-call engineer
    
  - name: Sprint Velocity Drop
    condition: current_velocity < (average_velocity * 0.7)
    action:
      - Notify delivery lead
      - Create retrospective issue
    
  - name: High WIP Violation
    condition: wip_count > (wip_limit * 1.5)
    action:
      - Block new issue assignment
      - Alert team lead
```

## Best Practices

### 1. Dashboard Maintenance
- Review metrics weekly
- Update thresholds quarterly
- Archive old dashboards
- Document metric changes

### 2. Data Quality
- Ensure consistent labeling
- Regular data validation
- Automate data collection
- Monitor data gaps

### 3. Stakeholder Communication
- Tailor views to audience
- Provide context for metrics
- Focus on trends, not points
- Include actionable insights

### 4. Continuous Improvement
- Gather feedback on reports
- A/B test dashboard layouts
- Iterate on metric definitions
- Automate repetitive analysis