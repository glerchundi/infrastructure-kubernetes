output "kube-master-lb" {
    value = "${google_compute_address.kube-master-lb.address}"
}

output "kube-worker-lb" {
    value = "${google_compute_address.kube-worker-lb.address}"
}
