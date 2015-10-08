provider "google" {
    account_file = "${file("${var.file-account}")}"
    project      = "${var.project}"
    region       = "${var.region}"
}

resource "google_compute_network" "kube-network" {
    name       = "${var.kube-network-name}"
    ipv4_range = "${var.kube-network-ipv4-range}"
}

resource "google_compute_firewall" "kube-allow-ssh-from-anywhere" {
    name          = "kube-allow-ssh-from-anywhere"
    network       = "${google_compute_network.kube-network.name}"
    source_ranges = [ "0.0.0.0/0" ]

    allow {
        protocol = "tcp"
        ports = [ "22" ]
    }
}

resource "google_compute_firewall" "kube-allow-apiserver-from-anywhere" {
    name          = "kube-allow-apiserver-from-anywhere"
    network       = "${google_compute_network.kube-network.name}"
    source_ranges = [ "0.0.0.0/0" ]

    allow {
        protocol = "tcp"
        ports = [ "443" ]
    }
}

resource "google_compute_firewall" "kube-allow-internal" {
    name          = "kube-allow-internal"
    network       = "${google_compute_network.kube-network.name}"
    source_ranges = [ "10.0.0.0/8" ]

    allow {
        protocol = "icmp"
    }

    allow {
        protocol = "tcp"
        ports = [ "1-65535" ]
    }

    allow {
        protocol = "udp"
        ports = [ "1-65535" ]
    }
}

#
# MASTER/S
#

resource "template_file" "kube-master-userdata" {
    filename = "${format("%s/%s", path.module, "files/kube-master.yml")}"
    vars {

        #
        # parameters
        #

        dns-service-ip   = "10.3.0.10"
        etcd-endpoints   = "${var.etcd-endpoints}"
        service-ip-range = "10.3.0.0/24"
        pod-network      = "10.2.0.0/16"
        fleet-metadata   = "${var.kube-master-tags}"
        k8s-prefix       = "/kubernetes.io"
        update-group     = "${var.coreos-update-group}"
        update-server    = "${var.coreos-update-server}"

        #
        # files
        #

        ca-cert               = "${base64enc(gzip(file(var.file-ca-cert)))}"
        api-server-cert       = "${base64enc(gzip(file(var.file-kube-api-server-cert)))}"
        api-server-key        = "${base64enc(gzip(file(var.file-kube-api-server-key)))}"
        etcd-ca-cert-file     = "/etc/ssl/etcd/ca.pem"
        etcd-ca-cert          = "${base64enc(gzip(file(var.file-kube-master-etcd-ca-cert)))}"
        etcd-client-cert-file = "/etc/ssl/etcd/client.pem"
        etcd-client-cert      = "${base64enc(gzip(file(var.file-kube-master-etcd-client-cert)))}"
        etcd-client-key-file  = "/etc/ssl/etcd/client.key.pem"
        etcd-client-key       = "${base64enc(gzip(file(var.file-kube-master-etcd-client-key)))}"
    }
}

resource "google_compute_instance_template" "kube-master-tmpl" {
    name           = "${var.kube-master-name-prefix}"
    machine_type   = "${var.machine_type}"
    can_ip_forward = false
    tags           = [ "${split(",", replace(format("%s", var.kube-master-tags), "/[^,]+=/", ""))}" ]

    disk {
        source_image = "${var.coreos-image}"
        type         = "pd-ssd"
        disk_size_gb = 200
        auto_delete  = true
    }

    network_interface {
        network = "${google_compute_network.kube-network.self_link}"
        access_config {
            // Ephemeral IP
        }
    }

    metadata {
        user-data = "${element(template_file.kube-master-userdata.*.rendered, count.index)}"
        sshKeys   = "${file(var.file-kube-ssh-pub-key)}"
    }

    service_account {
        scopes = [ "compute-rw" ]
    }
}

resource "google_compute_target_pool" "kube-master-pool" {
    name = "kube-master-pool"
}

resource "google_compute_instance_group_manager" "kube-master-grp" {
    name               = "${var.kube-master-name-prefix}"
    base_instance_name = "${var.kube-master-name-prefix}"
    instance_template  = "${google_compute_instance_template.kube-master-tmpl.self_link}"
    zone               = "${var.region}-f"
    target_pools       = ["${google_compute_target_pool.kube-master-pool.self_link}"]
}

resource "google_compute_autoscaler" "kube-master-autoscaler" {
    name   = "${var.kube-master-name-prefix}"
    zone   = "${google_compute_instance_group_manager.kube-master-grp.zone}"
    target = "${google_compute_instance_group_manager.kube-master-grp.self_link}"

    autoscaling_policy = {
        min_replicas = "${var.kube-master-min-replicas}"
        max_replicas = "${var.kube-master-max-replicas}"
        cooldown_period = 60
        cpu_utilization = {
            target = 0.5
        }
    }
}

resource "google_compute_address" "kube-master-lb" {
    name = "kube-master-lb"
}

resource "google_compute_forwarding_rule" "kube-master-rule" {
    name       = "kube-master-rule"
    ip_address = "${google_compute_address.kube-master-lb.address}"
    port_range = "443"
    target     = "${google_compute_target_pool.kube-master-pool.self_link}"
}

#
# WORKERS
#

resource "template_file" "kube-worker-userdata" {
    filename = "${format("%s/%s", path.module, "files/kube-worker.yml")}"
    vars {

        #
        # parameters
        #

        master-endpoint = "${var.kube-master-endpoint}"
        dns-service-ip  = "10.3.0.10"
        etcd-endpoints  = "${var.etcd-endpoints}"
        fleet-metadata  = "${var.kube-worker-tags}"
        update-group    = "${var.coreos-update-group}"
        update-server   = "${var.coreos-update-server}"

        #
        # files
        #

        ca-chain-cert         = "${base64enc(gzip(file(var.file-ca-cert)))}"
        worker-cert           = "${base64enc(gzip(file(var.file-kube-worker-client-cert)))}"
        worker-key            = "${base64enc(gzip(file(var.file-kube-worker-client-key)))}"
        etcd-ca-cert-file     = "/etc/ssl/etcd/ca.pem"
        etcd-ca-cert          = "${base64enc(gzip(file(var.file-kube-worker-etcd-ca-cert)))}"
        etcd-client-cert-file = "/etc/ssl/etcd/client.pem"
        etcd-client-cert      = "${base64enc(gzip(file(var.file-kube-worker-etcd-client-cert)))}"
        etcd-client-key-file  = "/etc/ssl/etcd/client.key.pem"
        etcd-client-key       = "${base64enc(gzip(file(var.file-kube-worker-etcd-client-key)))}"
    }
}

resource "google_compute_instance_template" "kube-worker-tmpl" {
    name           = "${var.kube-worker-name-prefix}"
    machine_type   = "${var.machine_type}"
    can_ip_forward = false
    tags           = [ "${split(",", replace(format("%s", var.kube-worker-tags), "/[^,]+=/", ""))}" ]

    disk {
        source_image = "${var.coreos-image}"
        type         = "pd-ssd"
        disk_size_gb = 200
        auto_delete  = true
    }

    network_interface {
        network = "${google_compute_network.kube-network.self_link}"
        access_config {
            // Ephemeral IP
        }
    }

    metadata {
        user-data = "${element(template_file.kube-worker-userdata.*.rendered, count.index)}"
        sshKeys   = "${file(var.file-kube-ssh-pub-key)}"
    }
}

resource "google_compute_target_pool" "kube-worker-pool" {
    name = "kube-worker-pool"
}

resource "google_compute_instance_group_manager" "kube-worker-grp" {
    name               = "${var.kube-worker-name-prefix}"
    base_instance_name = "${var.kube-worker-name-prefix}"
    instance_template  = "${google_compute_instance_template.kube-worker-tmpl.self_link}"
    zone               = "${var.region}-f"
    target_pools       = ["${google_compute_target_pool.kube-worker-pool.self_link}"]
}

resource "google_compute_autoscaler" "kube-worker-autoscaler" {
    name   = "${var.kube-worker-name-prefix}"
    zone   = "${google_compute_instance_group_manager.kube-worker-grp.zone}"
    target = "${google_compute_instance_group_manager.kube-worker-grp.self_link}"

    autoscaling_policy = {
        min_replicas = "${var.kube-worker-min-replicas}"
        max_replicas = "${var.kube-worker-max-replicas}"
        cooldown_period = 60
        cpu_utilization = {
            target = 0.5
        }
    }
}

resource "google_compute_address" "kube-worker-lb" {
    name = "kube-worker-lb"
}

resource "google_compute_forwarding_rule" "kube-worker-rule" {
    name       = "kube-worker-rule"
    ip_address = "${google_compute_address.kube-worker-lb.address}"
    port_range = "1-65535"
    target     = "${google_compute_target_pool.kube-worker-pool.self_link}"
}