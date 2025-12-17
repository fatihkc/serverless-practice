# CloudWatch Dashboard for SRE Observability
# Implements the Four Golden Signals: Latency, Traffic, Errors, Saturation

resource "aws_cloudwatch_dashboard" "sre_dashboard" {
  dashboard_name = "${var.project_name}-sre-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # ==================== GOLDEN SIGNAL: LATENCY ====================
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 0
        properties = {
          title   = "🚀 API Latency (p50, p95, p99)"
          region  = var.aws_region
          period  = 60
          stat    = "Average"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              label = "Seconds"
              min   = 0
            }
          }
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", {
              stat  = "p50"
              label = "p50 (median)"
              color = "#2ca02c"
            }],
            ["...", {
              stat  = "p95"
              label = "p95"
              color = "#ff7f0e"
            }],
            ["...", {
              stat  = "p99"
              label = "p99"
              color = "#d62728"
            }]
          ]
          annotations = {
            horizontal = [
              {
                label = "SLO Target: 500ms"
                value = 0.5
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # Lambda Latency
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 12
        y      = 0
        properties = {
          title  = "⚡ Lambda Duration (p50, p95, p99)"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Milliseconds"
              min   = 0
            }
          }
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "picus-dev-delete", {
              stat  = "p50"
              label = "p50"
              color = "#2ca02c"
            }],
            ["...", {
              stat  = "p95"
              label = "p95"
              color = "#ff7f0e"
            }],
            ["...", {
              stat  = "p99"
              label = "p99"
              color = "#d62728"
            }]
          ]
        }
      },

      # ==================== GOLDEN SIGNAL: TRAFFIC ====================
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 6
        properties = {
          title  = "📊 Request Rate (requests/minute)"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Requests"
              min   = 0
            }
          }
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", {
              stat  = "Sum"
              label = "Total Requests"
              color = "#1f77b4"
            }]
          ]
        }
      },

      # Lambda Invocations
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 12
        y      = 6
        properties = {
          title  = "🔄 Lambda Invocations"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Invocations"
              min   = 0
            }
          }
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "picus-dev-delete", {
              label = "DELETE Invocations"
              color = "#1f77b4"
            }],
            [".", "ConcurrentExecutions", ".", ".", {
              stat  = "Average"
              label = "Concurrent Executions"
              color = "#ff7f0e"
            }]
          ]
        }
      },

      # ==================== GOLDEN SIGNAL: ERRORS ====================
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 12
        properties = {
          title  = "❌ Error Rate (5xx responses)"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Errors"
              min   = 0
            }
          }
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", {
              stat  = "Sum"
              label = "Target 5xx Errors"
              color = "#d62728"
            }],
            [".", "HTTPCode_Target_4XX_Count", {
              stat  = "Sum"
              label = "Target 4xx Errors"
              color = "#ff7f0e"
            }]
          ]
          annotations = {
            horizontal = [
              {
                label = "Alert Threshold: 10 errors/min"
                value = 10
                color = "#d62728"
              }
            ]
          }
        }
      },

      # Success Rate Percentage
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 12
        y      = 12
        properties = {
          title  = "✅ Success Rate (SLI: 99.9% target)"
          region = var.aws_region
          period = 300
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Success %"
              min   = 99.0
              max   = 100.0
            }
          }
          metrics = [
            [{
              expression = "100 - (m1 / m2 * 100)"
              label      = "Success Rate"
              id         = "e1"
              color      = "#2ca02c"
            }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", {
              id      = "m1"
              visible = false
            }],
            [".", "RequestCount", {
              id      = "m2"
              visible = false
            }]
          ]
          annotations = {
            horizontal = [
              {
                label = "SLO: 99.9%"
                value = 99.9
                fill  = "below"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # Lambda Errors
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 18
        properties = {
          title  = "🚨 Lambda Errors & Throttles"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Count"
              min   = 0
            }
          }
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", "picus-dev-delete", {
              label = "Errors"
              color = "#d62728"
            }],
            [".", "Throttles", ".", ".", {
              label = "Throttles"
              color = "#ff7f0e"
            }],
            [".", "DeadLetterErrors", ".", ".", {
              label = "DLQ Errors"
              color = "#8c564b"
            }]
          ]
        }
      },

      # Lambda Success Rate
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 12
        y      = 18
        properties = {
          title  = "✔️ Lambda Success Rate"
          region = var.aws_region
          period = 300
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Success %"
              min   = 99.0
              max   = 100.0
            }
          }
          metrics = [
            [{
              expression = "100 - (errors / invocations * 100)"
              label      = "Success Rate"
              id         = "successRate"
              color      = "#2ca02c"
            }],
            ["AWS/Lambda", "Errors", "FunctionName", "picus-dev-delete", {
              id      = "errors"
              visible = false
            }],
            [".", "Invocations", ".", ".", {
              id      = "invocations"
              visible = false
            }]
          ]
        }
      },

      # ==================== GOLDEN SIGNAL: SATURATION ====================
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 24
        properties = {
          title  = "💻 ECS Task CPU Utilization"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Percent"
              min   = 0
              max   = 100
            }
          }
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-service", "ClusterName", "${var.project_name}-cluster", {
              label = "CPU Utilization"
              color = "#1f77b4"
            }]
          ]
          annotations = {
            horizontal = [
              {
                label = "Auto-scaling threshold: 70%"
                value = 70
                color = "#ff7f0e"
              },
              {
                label = "Critical: 90%"
                value = 90
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      },

      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 12
        y      = 24
        properties = {
          title  = "🧠 ECS Task Memory Utilization"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Percent"
              min   = 0
              max   = 100
            }
          }
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "${var.project_name}-service", "ClusterName", "${var.project_name}-cluster", {
              label = "Memory Utilization"
              color = "#2ca02c"
            }]
          ]
          annotations = {
            horizontal = [
              {
                label = "Auto-scaling threshold: 80%"
                value = 80
                color = "#ff7f0e"
              },
              {
                label = "Critical: 90%"
                value = 90
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # ECS Task Count
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 30
        properties = {
          title  = "📦 ECS Running Tasks"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Tasks"
              min   = 0
            }
          }
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ServiceName", "${var.project_name}-service", "ClusterName", "${var.project_name}-cluster", {
              label = "Running Tasks"
              color = "#1f77b4"
            }]
          ]
          annotations = {
            horizontal = [
              {
                label = "Desired: ${var.ecs_desired_count}"
                value = var.ecs_desired_count
                color = "#2ca02c"
              }
            ]
          }
        }
      },

      # DynamoDB Consumed Capacity
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 12
        y      = 30
        properties = {
          title  = "💾 DynamoDB Operations"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Count"
              min   = 0
            }
          }
          metrics = [
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", var.dynamodb_table_name, "Operation", "GetItem", {
              stat  = "SampleCount"
              label = "GetItem Requests"
              color = "#1f77b4"
            }],
            ["...", "PutItem", {
              stat  = "SampleCount"
              label = "PutItem Requests"
              color = "#2ca02c"
            }],
            ["...", "DeleteItem", {
              stat  = "SampleCount"
              label = "DeleteItem Requests"
              color = "#ff7f0e"
            }],
            ["...", "Scan", {
              stat  = "SampleCount"
              label = "Scan Requests"
              color = "#d62728"
            }]
          ]
        }
      },

      # DynamoDB Errors
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 36
        properties = {
          title  = "⚠️ DynamoDB Throttling & Errors"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Count"
              min   = 0
            }
          }
          metrics = [
            ["AWS/DynamoDB", "UserErrors", "TableName", var.dynamodb_table_name, {
              label = "User Errors (Throttling)"
              color = "#d62728"
            }],
            [".", "SystemErrors", ".", ".", {
              label = "System Errors"
              color = "#ff7f0e"
            }]
          ]
        }
      },

      # DynamoDB Latency
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 12
        y      = 36
        properties = {
          title  = "⏱️ DynamoDB Latency"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Milliseconds"
              min   = 0
            }
          }
          metrics = [
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", var.dynamodb_table_name, "Operation", "GetItem", {
              stat  = "Average"
              label = "GetItem"
              color = "#1f77b4"
            }],
            ["...", "PutItem", {
              stat  = "Average"
              label = "PutItem"
              color = "#2ca02c"
            }],
            ["...", "DeleteItem", {
              stat  = "Average"
              label = "DeleteItem"
              color = "#ff7f0e"
            }]
          ]
        }
      },

      # ALB Target Health
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 42
        properties = {
          title  = "🏥 ALB Target Health"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Count"
              min   = 0
            }
          }
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.ecs.arn_suffix, {
              label = "Healthy Hosts"
              color = "#2ca02c"
            }],
            [".", "UnHealthyHostCount", ".", ".", {
              label = "Unhealthy Hosts"
              color = "#d62728"
            }]
          ]
        }
      },

      # Active Connections
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 12
        y      = 42
        properties = {
          title  = "🔌 ALB Active Connections"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Connections"
              min   = 0
            }
          }
          metrics = [
            ["AWS/ApplicationELB", "ActiveConnectionCount", {
              label = "Active Connections"
              color = "#1f77b4"
            }],
            [".", "NewConnectionCount", {
              label = "New Connections"
              color = "#2ca02c"
            }],
            [".", "RejectedConnectionCount", {
              label = "Rejected Connections"
              color = "#d62728"
            }]
          ]
        }
      }
    ]
  })

  depends_on = [
    aws_ecs_service.app,
    aws_lb.main,
    aws_dynamodb_table.picus_data
  ]
}
