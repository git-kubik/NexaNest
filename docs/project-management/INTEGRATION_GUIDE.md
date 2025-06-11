# Integration Guidelines

## Overview

This guide covers integrating GitHub project management with external tools commonly used in cloud services delivery.

## Slack Integration

### Setup Instructions

1. **Install GitHub App for Slack**
   ```bash
   /github subscribe nexanest/nexanest issues pulls deployments
   ```

2. **Configure Notifications**
   ```bash
   # Critical issues
   /github subscribe nexanest/nexanest issues +label:"priority: critical"
   
   # Scope changes
   /github subscribe nexanest/nexanest issues +label:"scope-change"
   
   # Blocked items
   /github subscribe nexanest/nexanest issues +label:"status: blocked"
   ```

3. **Create Webhook for Custom Alerts**
   ```javascript
   // webhook-handler.js
   const { IncomingWebhook } = require('@slack/webhook');
   const webhook = new IncomingWebhook(process.env.SLACK_WEBHOOK_URL);

   exports.handleGitHubWebhook = async (event) => {
     if (event.action === 'labeled' && event.label.name === 'priority: critical') {
       await webhook.send({
         text: '🚨 Critical Issue Alert',
         attachments: [{
           color: 'danger',
           title: event.issue.title,
           title_link: event.issue.html_url,
           fields: [
             {
               title: 'Component',
               value: event.issue.labels.map(l => l.name).join(', '),
               short: true
             },
             {
               title: 'Created By',
               value: event.issue.user.login,
               short: true
             }
           ]
         }]
       });
     }
   };
   ```

### Slack Commands

```yaml
commands:
  - name: /nexanest-status
    description: Get current sprint status
    endpoint: https://api.nexanest.com/slack/status
    
  - name: /nexanest-blockers
    description: List all blocked items
    endpoint: https://api.nexanest.com/slack/blockers
    
  - name: /nexanest-assign
    description: Assign an issue to yourself
    usage: /nexanest-assign [issue-number]
    endpoint: https://api.nexanest.com/slack/assign
```

## Jira Integration

### Bi-directional Sync Setup

1. **Install GitHub for Jira App**
   - Navigate to Jira → Apps → Find new apps
   - Search for "GitHub for Jira"
   - Install and configure with repository access

2. **Configure Field Mapping**
   ```json
   {
     "field_mappings": {
       "github_to_jira": {
         "title": "summary",
         "body": "description",
         "labels": "labels",
         "milestone": "fixVersion",
         "assignee": "assignee"
       },
       "jira_to_github": {
         "summary": "title",
         "description": "body",
         "priority": "labels",
         "story_points": "project_field:story_points"
       }
     }
   }
   ```

3. **Sync Automation**
   ```yaml
   name: Jira Sync
   on:
     issues:
       types: [opened, edited, closed]
   
   jobs:
     sync-to-jira:
       runs-on: ubuntu-latest
       steps:
         - name: Sync Issue to Jira
           uses: atlassian/gajira-create@v2.0.1
           with:
             project: NEXA
             issuetype: ${{ github.event.issue.labels[0].name }}
             summary: ${{ github.event.issue.title }}
             description: ${{ github.event.issue.body }}
   ```

## Microsoft Teams Integration

### Teams Connector Setup

1. **Add GitHub Connector**
   - In Teams channel → Connectors → GitHub
   - Configure repository and events

2. **Adaptive Cards for Rich Notifications**
   ```json
   {
     "@type": "MessageCard",
     "@context": "https://schema.org/extensions",
     "summary": "Issue #{{ issue.number }} requires attention",
     "themeColor": "FF0000",
     "sections": [{
       "activityTitle": "{{ issue.title }}",
       "activitySubtitle": "Priority: {{ priority }}",
       "facts": [
         {
           "name": "Assigned to",
           "value": "{{ assignee }}"
         },
         {
           "name": "Component",
           "value": "{{ component }}"
         }
       ],
       "potentialAction": [{
         "@type": "OpenUri",
         "name": "View Issue",
         "targets": [{
           "os": "default",
           "uri": "{{ issue.url }}"
         }]
       }]
     }]
   }
   ```

## Monitoring Tools Integration

### Datadog Integration

1. **Install GitHub Integration**
   ```bash
   # In Datadog
   Integrations → GitHub → Configure
   # Add repository and PAT token
   ```

2. **Custom Metrics**
   ```python
   # datadog_metrics.py
   from datadog import initialize, api
   
   options = {
       'api_key': os.environ['DATADOG_API_KEY'],
       'app_key': os.environ['DATADOG_APP_KEY']
   }
   
   initialize(**options)
   
   def send_project_metrics(metrics):
       api.Metric.send([
           {
               'metric': 'github.issues.cycle_time',
               'points': metrics['cycle_time'],
               'tags': ['project:nexanest', f"team:{metrics['team']}"]
           },
           {
               'metric': 'github.issues.velocity',
               'points': metrics['velocity'],
               'tags': ['project:nexanest', 'sprint:current']
           }
       ])
   ```

3. **Dashboard Configuration**
   ```json
   {
     "widgets": [
       {
         "definition": {
           "type": "timeseries",
           "requests": [{
             "q": "avg:github.issues.cycle_time{project:nexanest} by {team}"
           }],
           "title": "Cycle Time by Team"
         }
       }
     ]
   }
   ```

### Grafana Integration

1. **Add GitHub Data Source**
   ```yaml
   apiVersion: 1
   datasources:
     - name: GitHub
       type: github-datasource
       access: proxy
       url: https://api.github.com
       basicAuth: true
       basicAuthUser: $GITHUB_USER
       secureJsonData:
         basicAuthPassword: $GITHUB_TOKEN
   ```

2. **Project Metrics Dashboard**
   ```json
   {
     "panels": [
       {
         "title": "Issue Status Distribution",
         "targets": [{
           "query": "issues",
           "repository": "nexanest/nexanest",
           "refId": "A"
         }],
         "transformations": [{
           "id": "groupBy",
           "options": {
             "fields": {
               "state": {
                 "aggregations": ["count"]
               }
             }
           }
         }]
       }
     ]
   }
   ```

## CI/CD Integration

### Jenkins Integration

```groovy
// Jenkinsfile
pipeline {
    agent any
    
    stages {
        stage('Update GitHub Issue') {
            steps {
                script {
                    def issueNumber = env.GITHUB_ISSUE_NUMBER
                    if (issueNumber) {
                        githubNotify(
                            status: 'PENDING',
                            description: 'Build started',
                            context: 'continuous-integration/jenkins'
                        )
                    }
                }
            }
        }
        
        stage('Build') {
            steps {
                sh 'make build'
            }
            post {
                success {
                    updateGitHubIssue(
                        issue: env.GITHUB_ISSUE_NUMBER,
                        labels: ['status: testing']
                    )
                }
                failure {
                    updateGitHubIssue(
                        issue: env.GITHUB_ISSUE_NUMBER,
                        labels: ['status: blocked', 'build-failed']
                    )
                }
            }
        }
    }
}
```

### GitHub Actions to External Systems

```yaml
name: External Integrations
on:
  issues:
    types: [labeled]

jobs:
  notify-external:
    runs-on: ubuntu-latest
    steps:
      - name: Notify PagerDuty
        if: contains(github.event.label.name, 'incident')
        uses: PagerDuty/pagerduty-change-events-action@v2
        with:
          integration-key: ${{ secrets.PAGERDUTY_KEY }}
          
      - name: Create ServiceNow Ticket
        if: contains(github.event.label.name, 'infrastructure')
        run: |
          curl -X POST https://instance.service-now.com/api/now/table/incident \
            -H "Authorization: Bearer ${{ secrets.SERVICENOW_TOKEN }}" \
            -H "Content-Type: application/json" \
            -d '{
              "short_description": "${{ github.event.issue.title }}",
              "description": "${{ github.event.issue.body }}",
              "urgency": "2",
              "impact": "2"
            }'
```

## Time Tracking Integration

### Toggl Integration

```javascript
// toggl-sync.js
const TogglClient = require('toggl-api');
const toggl = new TogglClient({ apiToken: process.env.TOGGL_TOKEN });

async function startTimeEntry(issueNumber, issueTitle) {
  const entry = await toggl.startTimeEntry({
    description: `#${issueNumber}: ${issueTitle}`,
    tags: ['github', 'nexanest'],
    pid: process.env.TOGGL_PROJECT_ID
  });
  
  // Add time entry ID to GitHub issue
  await github.rest.issues.createComment({
    owner: 'nexanest',
    repo: 'nexanest',
    issue_number: issueNumber,
    body: `⏱️ Time tracking started (ID: ${entry.id})`
  });
}
```

## API Integration Framework

### Generic Webhook Handler

```python
# webhook_router.py
from flask import Flask, request
import json

app = Flask(__name__)

INTEGRATIONS = {
    'slack': SlackHandler(),
    'teams': TeamsHandler(),
    'jira': JiraHandler(),
    'datadog': DatadogHandler()
}

@app.route('/webhook/<integration>', methods=['POST'])
def handle_webhook(integration):
    if integration not in INTEGRATIONS:
        return {'error': 'Unknown integration'}, 404
    
    event = request.json
    handler = INTEGRATIONS[integration]
    
    try:
        result = handler.process(event)
        return {'status': 'success', 'result': result}, 200
    except Exception as e:
        return {'error': str(e)}, 500

class IntegrationHandler:
    def process(self, event):
        if event['action'] == 'opened':
            return self.handle_opened(event)
        elif event['action'] == 'closed':
            return self.handle_closed(event)
        # ... more event handlers
```

## Security Considerations

### API Token Management

```yaml
# Store in GitHub Secrets
secrets:
  - SLACK_WEBHOOK_URL
  - JIRA_API_TOKEN
  - DATADOG_API_KEY
  - SERVICENOW_TOKEN

# Rotate tokens quarterly
# Use least-privilege access
# Audit token usage regularly
```

### Webhook Security

```javascript
// Verify webhook signatures
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, secret) {
  const hmac = crypto.createHmac('sha256', secret);
  hmac.update(JSON.stringify(payload));
  const digest = `sha256=${hmac.digest('hex')}`;
  
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(digest)
  );
}
```

## Best Practices

### 1. Integration Design
- Use webhooks over polling
- Implement retry logic
- Handle rate limits gracefully
- Log all integration events

### 2. Data Consistency
- Single source of truth (GitHub)
- Sync conflicts resolution
- Regular reconciliation
- Audit trails

### 3. Performance
- Async processing
- Batch operations
- Cache external data
- Monitor latency

### 4. Maintenance
- Document all integrations
- Test integration health
- Version external APIs
- Plan for deprecations