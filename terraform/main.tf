locals {
  name_prefix = var.project_name

  kube_prereq_user_data = <<-EOT
    #!/bin/bash
    set -eux

    export DEBIAN_FRONTEND=noninteractive

    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab

    cat <<EOF | tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF
    modprobe overlay
    modprobe br_netfilter

    cat <<EOF | tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF
    sysctl --system

    apt-get update -y
    apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${var.kubernetes_version}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${var.kubernetes_version}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update -y
    apt-get install -y containerd kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd

    systemctl enable kubelet

    cat <<'EOS' > /home/ubuntu/init-master.sh
    #!/bin/bash
    set -eux

    MASTER_PRIVATE_IP=$(hostname -I | awk '{print $1}')
    kubeadm init --apiserver-advertise-address "$MASTER_PRIVATE_IP" --pod-network-cidr=192.168.0.0/16

    mkdir -p /home/ubuntu/.kube
    cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube

    sudo -u ubuntu kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
    kubeadm token create --print-join-command > /home/ubuntu/join-command.sh
    chmod +x /home/ubuntu/join-command.sh
    chown ubuntu:ubuntu /home/ubuntu/join-command.sh
    EOS

    chmod +x /home/ubuntu/init-master.sh
    chown ubuntu:ubuntu /home/ubuntu/init-master.sh

    cat <<'EOS' > /home/ubuntu/join-worker.sh
    #!/bin/bash
    set -eux
    echo "Run the join command from master node here."
    echo "Example: sudo kubeadm join <master-private-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
    EOS

    chmod +x /home/ubuntu/join-worker.sh
    chown ubuntu:ubuntu /home/ubuntu/join-worker.sh
  EOT
}

resource "aws_vpc" "quickhire_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.quickhire_vpc.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.quickhire_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-a"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.quickhire_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-b"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.quickhire_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "subnet_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "k8s_sg" {
  name        = "${local.name_prefix}-k8s-sg"
  description = "Kubeadm Kubernetes security group"
  vpc_id      = aws_vpc.quickhire_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
    description = "SSH"
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
    description = "Kubernetes API"
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NodePort range"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Internal VPC traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "master" {
  ami                         = var.instance_ami
  instance_type               = var.master_instance_type
  subnet_id                   = aws_subnet.public_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data                   = local.kube_prereq_user_data

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${local.name_prefix}-master"
    Role = "master"
  }
}

resource "aws_instance" "worker1" {
  ami                         = var.instance_ami
  instance_type               = var.worker_instance_type
  subnet_id                   = aws_subnet.public_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data                   = local.kube_prereq_user_data

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }

  tags = {
    Name = "${local.name_prefix}-worker-1"
    Role = "worker"
  }
}

resource "aws_instance" "worker2" {
  ami                         = var.instance_ami
  instance_type               = var.worker_instance_type
  subnet_id                   = aws_subnet.public_subnet_b.id
  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data                   = local.kube_prereq_user_data

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }

  tags = {
    Name = "${local.name_prefix}-worker-2"
    Role = "worker"
  }
}
