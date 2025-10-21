resource "aws_cloudwatch_metric_alarm" "syslog" {
  alarm_name                = "syslog"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Average"
  threshold                 = 0.0001
  alarm_description         = "This metric monitors ec2 cpu utilization"
  treat_missing_data        = "breaching" 
  dimensions = { 
    InstanceId = aws_instance.syslog-server.id 
    }
  depends_on = [aws_instance.syslog-server]
}