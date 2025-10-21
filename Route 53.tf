resource "aws_route53_zone" "syslog" {
  name = "wally.com"

  vpc {
    vpc_id = module.vpc_japan.vpc_id
    vpc_region = "ap-northeast-1"
  }
  vpc {
    vpc_id = module.vpc_NewYork.vpc_id
    vpc_region = "us-east-1"
  }
}

resource "aws_route53_record" "syslog" {
  zone_id = aws_route53_zone.syslog.zone_id
  name    = "wally.com"
  type    = "A"
  ttl     = 30
  records = [aws_instance.syslog-server.private_ip]
   set_identifier = "primary-syslog-server"
  failover_routing_policy {
    type = "PRIMARY"
  }
    health_check_id = aws_route53_health_check.syslog.id
    depends_on = [
      aws_route53_zone.syslog,
      aws_route53_health_check.syslog,
      aws_cloudwatch_metric_alarm.syslog,
      aws_instance.syslog-server
      ]
}


resource "aws_route53_record" "syslog2" {
  zone_id = aws_route53_zone.syslog.zone_id
  name    = "wally.com"
  type    = "A"
  ttl     = 30
  records = [aws_instance.syslog-server2.private_ip]
    set_identifier  = "secondary-syslog-server"
  failover_routing_policy {
    type            = "SECONDARY"
  }
  depends_on = [
    aws_route53_zone.syslog,
    aws_instance.syslog-server2
  ]
}

