variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "compartment_ocid" {}
variable "region" {default = "us-ashburn-1"}
variable "AD" {default = "FsFj:US-ASHBURN-AD-1"}
variable "AD2" {default = "FsFj:US-ASHBURN-AD-2"}
# ------ Create a new VCN
variable "VCN-CIDR" { default = "10.0.0.0/16" }

provider "oci" {
 tenancy_ocid = "${var.tenancy_ocid}"
 user_ocid = "${var.user_ocid}"
 fingerprint = "${var.fingerprint}"
 private_key_path = "${var.private_key_path}"
 region = "us-ashburn-1"
}

resource "oci_core_virtual_network" "vcn" {
 cidr_block = "10.0.0.0/16"
 dns_label = "tfvcn"
 compartment_id = "${var.compartment_ocid}"
 display_name = "vcn"
}
