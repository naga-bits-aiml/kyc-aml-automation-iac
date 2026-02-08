output "kyc_onboarding_vm_ip" {
  value       = google_compute_instance.kyc_onboarding_vm.network_interface[0].access_config[0].nat_ip
  description = "External IP of the KYC onboarding VM"
}

output "kyc_web_agent_vm_ip" {
  value       = google_compute_instance.kyc_web_agent_vm.network_interface[0].access_config[0].nat_ip
  description = "External IP of the KYC web agent VM"
}

output "kyc_instance_group_id" {
  value       = google_compute_instance_group.kyc_instance_group.id
  description = "ID of the KYC instance group"
}

output "kyc_instance_group_name" {
  value       = google_compute_instance_group.kyc_instance_group.name
  description = "Name of the KYC instance group"
}
