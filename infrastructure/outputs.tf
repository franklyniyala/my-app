output "ssh_command" {
  value = "ssh -i jay.pem ec2-user@${aws_instance.my-app-ec2-server.public_ip}"
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca" {
  value = aws_eks_cluster.this.certificate_authority[0].data

}

output "cluster_name" {
  value = aws_eks_cluster.this.name
}