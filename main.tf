provider "aws" {
  region = "us-east-2"
}

# ✅ SNS Topic for Email Alerts
resource "aws_sns_topic" "cpu_alerts" {
  name = "cpu-anomaly-alerts"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.cpu_alerts.arn
  protocol  = "email"
  endpoint  = "ashish.9.sharma@niit.com"  # 🔹 Replace with your email
}

# ✅ EC2 Instance with CloudWatch Agent and Stress Tool
resource "aws_instance" "ec2_instance" {
  ami           = "ami-0cb91c7de36eed2cb"  # Replace with latest Amazon Linux AMI
  instance_type = "t2.micro"
  key_name      = "test1"  # Replace with your key pair

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y stress

              # ✅ Install CloudWatch Agent
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
              sudo dpkg -i amazon-cloudwatch-agent.deb
              sudo systemctl enable amazon-cloudwatch-agent
              sudo systemctl start amazon-cloudwatch-agent
              EOF

  tags = {
    Name = "Anomaly-Detection-EC2"
  }
}

# ✅ Anomaly Detection for CPU Spikes
resource "aws_cloudwatch_metric_alarm" "cpu_anomaly" {
  alarm_name          = "CPU_Anomaly_Detection"
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "ad1"
  alarm_description   = "Triggers when CPU spikes beyond anomaly threshold"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.cpu_alerts.arn]  # 🔹 Sends email alert

  metric_query {
    id          = "m1"
    return_data = true
    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      period      = 60
      stat        = "Average"
      dimensions = {
        InstanceId = aws_instance.ec2_instance.id
      }
    }
  }

  metric_query {
    id          = "ad1"
    return_data = true
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
  }
}

# ✅ **CPU Utilization > 95% Alarm (Sends Email)**
resource "aws_cloudwatch_metric_alarm" "cpu_threshold" {
  alarm_name          = "CPU_Threshold_Exceeded"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 75.0  # 🔥 **Triggers when CPU > 75%**
  alarm_description   = "Triggers when CPU utilization exceeds 75%"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.cpu_alerts.arn]  # ✅ Sends email

  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  period      = 60
  statistic   = "Average"
  dimensions = {
    InstanceId = aws_instance.ec2_instance.id
  }
}

