variable "project" {
    default = "sheriff-woody"
}

#
# files
#

variable "file-account" {
    default = "files/sheriff-woody.json"
}

variable "file-ca-cert" {
    default = "files/ca.pem"
}

variable "file-kube-api-server-cert" {
    default = "files/kube-api.server.pem"
}

variable "file-kube-api-server-key" {
    default = "files/kube-api.server.key.pem"
}

variable "file-kube-master-etcd-ca-cert" {
    default = "files/ca.pem"
}

variable "file-kube-master-etcd-client-cert" {
    default = "files/kube-master-etcd.client.pem"
}

variable "file-kube-master-etcd-client-key" {
    default = "files/kube-master-etcd.client.key.pem"
}

variable "file-kube-worker-client-cert" {
    default = "files/kube-worker.client.pem"
}

variable "file-kube-worker-client-key" {
    default = "files/kube-worker.client.key.pem"
}

variable "file-kube-worker-etcd-ca-cert" {
    default = "files/ca.pem"
}

variable "file-kube-worker-etcd-client-cert" {
    default = "files/kube-worker-etcd.client.pem"
}

variable "file-kube-worker-etcd-client-key" {
    default = "files/kube-worker-etcd.client.key.pem"
}

variable "file-kube-ssh-pub-key" {
    default = "files/id_rsa.pub"
}

# infrastructure

variable "region" {
    default = "us-central1"
}

variable "etcd-endpoints" {
    default = ""
}

variable "kube-network-name" {
    default = "kube-network"
}

variable "kube-network-ipv4-range" {
    default = "10.0.0.0/16"
}

variable "kube-master-name-prefix" {
    default = "kube-master"
}

variable "kube-master-tags" {
    default = "role=kube-master,environment=production"
}

variable "kube-master-min-replicas" {
    default = 1
}

variable "kube-master-max-replicas" {
    default = 1
}

variable "kube-master-endpoint" {
    default = ""
}

variable "kube-worker-name-prefix" {
    default = "kube-worker"
}

variable "kube-worker-tags" {
    default = "role=kube-worker,environment=production"
}

variable "kube-worker-min-replicas" {
    default = 3
}

variable "kube-worker-max-replicas" {
    default = 3
}

variable "machine_type" {
    default = "n1-standard-1"
}

variable "coreos-image" {
    default = "coreos-alpha-801-0-0-v20150910"
}

variable "coreos-update-group" {
    default = "stable"
}

variable "coreos-update-server" {
    default = "https://public.update.core-os.net/v1/update/"
}
