#------ Load Balancer ------

#---Public Load Balancer---
resource "aws_lb" "public_load_balancer" {
  name               = "public_load_balancer"
  internal           = false
  load_balancer_type = "application"
#  security_groups    = ["${aws_security group.public_load_balancer_sg.id}"]
  subnets            = ["${aws_subnet.load_balancer_subnet1.id}"]
}



#---Public Load Balancer Target Group---
resource "aws_lb_target_group" "public_load_balancer_tg" {
  name     = "public_load_balancer_tg"
  vpc_id   = "${aws_vpc.app_vpc.id}"
  port     = 80
  protocol = "HTTP"

  health_check {
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    internal            = 5
    timeout             = 4
    matcher             = "200-308"
  }
}



#---Target Group Attachments---
resource "aws_alb_target_group_attachment" "public_load_balancer_attachment" {
  target_group_arn = "${aws_lb_target_group.public_load_balancer_tg.id}"
#  target_id        = "${aws_instance.INSTANCE MADE BY AUTOSCALING GROUP}"
}

resource "aws_alb_target_group_attachment" "public_load_balancer_attachment" {
  target_group_arn = "${aws_lb_target_group.public_load_balancer_tg.id}"
#  target_id        = "${aws_instance.INSTANCE MADE BY AUTOSCALING GROUP}"
}



#---Load Balancer Certificate---
#resource "aws_lb_listener_certificate" "public_load_balancer_certificate" {
#  listener_arn    = "${aws_alb_listener.alb_front_https.arn}"
#  certificate_arn = "${aws_iam_server_certificate.url3_valouille_fr.arn}"
#}



#---Load Balancer Listener Redirect---
resource "aws_lb_listener" "public_load_balancer_redirect" {
  load_balancer_arn = "${aws_lb.public_load_balancer.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}



#---Load Balancer Listener HTTPS---
resource "aws_lb_listener" "public_load_balancer_https" {
  load_balancer_arn = "${aws_lb.public_load_balancer.id}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
#  certificate_arn   = "${aws_iam_server_certificate.CERTIFICATE ID WILL GO HERE}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.public_load_balancer_tg}"
  }
}



#---Application Load Balancer---

#RDS