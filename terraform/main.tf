terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.54"
    }
  }
}

variable "hetzner_token" {
  type        = string
  description = "Hetzner Cloud API token"
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
}

variable "db_node_count" {
  type = number
  description = "Number of DB nodes"
  default = 3
}

provider "hcloud" {
  token = var.hetzner_token
}

resource "hcloud_ssh_key" "benchmark" {
  name       = "benchmark-key"
  public_key = var.ssh_public_key
}

resource "hcloud_network" "db_network" {
  name     = "db-cluster-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "db_network_subnet" {
  network_id   = hcloud_network.db_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# Controller Server

resource "hcloud_server" "controller_server" {
  name        = "controller"
  server_type = "cpx32"
  image       = "ubuntu-22.04"
  location    = "nbg1"
  ssh_keys = [hcloud_ssh_key.benchmark.id]

  labels = {
    role = "controller"
  }
}

resource "hcloud_server_network" "controller_network" {
  server_id  = hcloud_server.controller_server.id
  network_id = hcloud_network.db_network.id
  ip         = "10.0.1.10"
}

# DB Nodes

resource "hcloud_server" "db_nodes" {
  count       = var.db_node_count
  name        = "db-node-${count.index}"
  server_type = "cpx32"
  image       = "ubuntu-22.04"
  location    = "nbg1"
  ssh_keys = [hcloud_ssh_key.benchmark.id]

  public_net {
    ipv4_enabled = false
  }

  labels = {
    role = "db"
    node = tostring(count.index)
  }
}

resource "hcloud_server_network" "db_network_attachment" {
  count      = var.db_node_count
  server_id  = hcloud_server.db_nodes[count.index].id
  network_id = hcloud_network.db_network.id
  ip         = "10.0.1.${20 + count.index}"
}

output "controller_public_ip" {
  description = "Public IP of controller node (SSH access)"
  value       = hcloud_server.controller_server.ipv4_address
}

output "controller_private_ip" {
  description = "Private IP inside cluster network"
  value       = hcloud_server_network.controller_network.ip
}

output "db_nodes_public_ips" {
  description = "Public IPs of database nodes"
  value = {
    for idx, server in hcloud_server.db_nodes :
    server.name => server.ipv6_address
  }
}

output "db_nodes_private_ips" {
  description = "Internal IPs of database nodes"
  value = {
    for idx, server in hcloud_server.db_nodes :
    server.name => hcloud_server_network.db_network_attachment[idx].ip
  }
}
