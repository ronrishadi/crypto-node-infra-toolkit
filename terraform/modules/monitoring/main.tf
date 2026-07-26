resource "aws_sns_topic" "alerts" {
  name = "${var.name}-node-alerts"
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name}-cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  period              = 300
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Sustained high CPU on the node instance - check for a stuck sync loop or runaway process before it becomes an outage."
  dimensions = {
    InstanceId = var.instance_id
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
  tags          = var.tags
}

# Disk usage isn't a native EC2 metric - it's expected to arrive as a custom
# metric published by scripts/node-healthcheck.sh under the same namespace
# the instance role is scoped to write to (see node-instance module).
resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "${var.name}-disk-usage-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 300
  metric_name         = "DiskUsedPercent"
  namespace           = var.metrics_namespace
  statistic           = "Maximum"
  threshold           = var.disk_alarm_threshold
  alarm_description   = "Chain-data volume is filling up. Left unchecked this stops the node, not just slows it down."
  dimensions = {
    InstanceId = var.instance_id
  }
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  treat_missing_data = "breaching" # a healthcheck that stops reporting is itself a signal, not silence.
  tags               = var.tags
}
