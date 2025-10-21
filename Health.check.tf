resource "aws_route53_health_check" "syslog" {
  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.syslog.alarm_name
  cloudwatch_alarm_region         = "ap-northeast-1"
  insufficient_data_health_status = "Unhealthy" #if the last known data point is set to "healthy", then it will assume it's healthly so this must be set to "Unhealthy"
  tags = {
    Name = "syslog"
  }
  depends_on = [
    aws_cloudwatch_metric_alarm.syslog,
    aws_instance.syslog-server
    ]
}