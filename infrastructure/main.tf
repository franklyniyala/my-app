resource "aws_instance" "my-app-ec2-server" {
  ami                         = "ami-01b14b7ad41e17ba4"
  instance_type               = "m7i-flex.large"
  subnet_id                   = aws_subnet.my-app-public-subnet[0].id
  vpc_security_group_ids      = [aws_security_group.my-app-sg.id]
  key_name                    = "jay"
  associate_public_ip_address = true

  tags = {
    Name = "my-app-ec2-server"
  }
}