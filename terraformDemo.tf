variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "compartment_ocid" {}
variable "region" {}

provider "oci" {
  auth   = "InstancePrincipal"
  region = "us-ashburn-1"
}

resource "oci_core_virtual_network" "VCN" {
  cidr_block     = "10.0.0.0/16"
  dns_label      = "VCN"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "VCN"
}

//Creating Internet and NAT gateways
resource "oci_core_internet_gateway" "IGW" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "IGW"
  enabled        = true
  vcn_id         = "${oci_core_virtual_network.VCN.id}"
}

resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.VCN.id}"
  display_name   = "nat_gateway"
}

//create two route tables
resource "oci_core_route_table" "PublicSubnetRT" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "PublicSubnetRT"
  vcn_id         = "${oci_core_virtual_network.VCN.id}"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.IGW.id}"
  }
}

resource "oci_core_route_table" "PrivateSubnetRT" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "PrivateSubnetRT"
  vcn_id         = "${oci_core_virtual_network.VCN.id}"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = "${oci_core_nat_gateway.nat_gateway.id}"
  }
}

//create securitylists for each subnet (bastion subnet, private db1 subnet, private db2 subnet)
resource "oci_core_security_list" "BastionSecurityList" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "BastionSecurityList"
  vcn_id         = "${oci_core_virtual_network.VCN.id}"

  ingress_security_rules = [
    {
      protocol    = "6"
      source      = "0.0.0.0/0"
      source_type = "CIDR_BLOCK"

      tcp_options {
        min = 22
        max = 22
      }
    },
    {
      protocol    = "1"
      source      = "10.0.0.0/16"
      source_type = "CIDR_BLOCK"

      icmp_options {
        type = 3
      }
    },
    {
      protocol    = "1"
      source      = "0.0.0.0/0"
      source_type = "CIDR_BLOCK"

      icmp_options {
        type = 3
        code = 4
      }
    },
  ]

  egress_security_rules = [{
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }]
}

resource "oci_core_security_list" "PrivateDB1SecurityList" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "PrivateDB1SecurityList"
  vcn_id         = "${oci_core_virtual_network.VCN.id}"

  ingress_security_rules = [
    {
      protocol    = "6"
      source      = "10.0.0.0/24"
      source_type = "CIDR_BLOCK"

      tcp_options {
        min = 22
        max = 22
      }
    },
    {
      protocol    = "6"
      source      = "10.0.2.0/24"
      source_type = "CIDR_BLOCK"

      tcp_options {
        min = 1521
        max = 1521
      }
    },
  ]

  egress_security_rules = [
    {
      destination      = "0.0.0.0/0"
      destination_type = "CIDR_BLOCK"
      protocol         = "all"
    },
    {
      destination      = "10.0.2.0/24"
      destination_type = "CIDR_BLOCK"
      protocol         = "6"

      tcp_options {
        min = 1521
        max = 1521
      }
    },
  ]
}

resource "oci_core_security_list" "PrivateDB2SecurityList" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "PrivateDB2SecurityList"
  vcn_id         = "${oci_core_virtual_network.VCN.id}"

  ingress_security_rules = [
    {
      protocol    = "6"
      source      = "10.0.0.0/24"
      source_type = "CIDR_BLOCK"

      tcp_options {
        min = 22
        max = 22
      }
    },
    {
      protocol    = "6"
      source      = "10.0.1.0/24"
      source_type = "CIDR_BLOCK"

      tcp_options {
        min = 1521
        max = 1521
      }
    },
  ]

  egress_security_rules = [
    {
      destination      = "0.0.0.0/0"
      destination_type = "CIDR_BLOCK"
      protocol         = "all"
    },
    {
      destination      = "10.0.1.0/24"
      destination_type = "CIDR_BLOCK"
      protocol         = "6"

      tcp_options {
        min = 1521
        max = 1521
      }
    },
  ]
}

//Bastion Subnet
resource "oci_core_subnet" "BastionSubnet" {
  availability_domain        = "ToGS:US-ASHBURN-AD-1"
  cidr_block                 = "10.0.0.0/24"
  compartment_id             = "${var.compartment_ocid}"
  display_name               = "BastionSubnet"
  dns_label                  = "bastionDNS"
  vcn_id                     = "${oci_core_virtual_network.VCN.id}"
  prohibit_public_ip_on_vnic = false
  route_table_id             = "${oci_core_route_table.PublicSubnetRT.id}"

  security_list_ids = [
    "${oci_core_security_list.BastionSecurityList.id}",
  ]
}

resource "oci_core_subnet" "webServerSubnet1" {
  availability_domain        = "ToGS:US-ASHBURN-AD-1"
  cidr_block                 = "10.0.3.0/24"
  compartment_id             = "${var.compartment_ocid}"
  display_name               = "webServerSubnet1"
  dns_label                  = "web1DNS"
  vcn_id                     = "${oci_core_virtual_network.VCN.id}"
  prohibit_public_ip_on_vnic = false
  route_table_id             = "${oci_core_route_table.PublicSubnetRT.id}"

  security_list_ids = [
    "${oci_core_security_list.BastionSecurityList.id}",
  ]
}

resource "oci_core_subnet" "webServerSubnet2" {
  availability_domain        = "ToGS:US-ASHBURN-AD-2"
  cidr_block                 = "10.0.4.0/24"
  compartment_id             = "${var.compartment_ocid}"
  display_name               = "webServerSubnet2"
  dns_label                  = "web2DNS"
  vcn_id                     = "${oci_core_virtual_network.VCN.id}"
  prohibit_public_ip_on_vnic = false
  route_table_id             = "${oci_core_route_table.PublicSubnetRT.id}"

  security_list_ids = [
    "${oci_core_security_list.BastionSecurityList.id}",
  ]
}

resource "oci_core_subnet" "db1Subnet" {
  availability_domain        = "ToGS:US-ASHBURN-AD-1"
  cidr_block                 = "10.0.1.0/24"
  compartment_id             = "${var.compartment_ocid}"
  display_name               = "db1Subnet"
  dns_label                  = "db1DNS"
  vcn_id                     = "${oci_core_virtual_network.VCN.id}"
  prohibit_public_ip_on_vnic = true
  route_table_id             = "${oci_core_route_table.PrivateSubnetRT.id}"

  security_list_ids = [
    "${oci_core_security_list.PrivateDB1SecurityList.id}",
  ]
}

resource "oci_core_subnet" "db2Subnet" {
  availability_domain        = "ToGS:US-ASHBURN-AD-2"
  cidr_block                 = "10.0.2.0/24"
  compartment_id             = "${var.compartment_ocid}"
  display_name               = "db2Subnet"
  dns_label                  = "db2DNS"
  vcn_id                     = "${oci_core_virtual_network.VCN.id}"
  prohibit_public_ip_on_vnic = true
  route_table_id             = "${oci_core_route_table.PrivateSubnetRT.id}"

  security_list_ids = [
    "${oci_core_security_list.PrivateDB2SecurityList.id}",
  ]
}

//provision two database systems

resource "oci_core_instance" "dbSystem1" {
  availability_domain = "ToGS:US-ASHBURN-AD-1"
  compartment_id      = "${var.compartment_ocid}"
  shape               = "VM.Standard2.4"

  metadata {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZgJClETAdRFuH4y/uRAgMLuLnn/QL07oZDBEEc9oxCdKCD9nH3GbKykQ+9RP9h29etzOfyDkRF6oB9Dh2ukzhEFcyBIkPVC1Lze1tVjtoXXms3fGpzrYPkq8UxDAwt+k66xuhptR9PSklJspyBEHYAClJN56t4zoRr/ZhJnafZmPQ41QfSWss8JGNiHlqRmlvRLgC/LwRY/q4E1ZE/VfR1RK5eDa6DZOu6UrjTf9fi3BIvoPcLgV7jPW/nFcOiGYSgJ/yq4Dpy8pcfs06DHqR43O4TlWXQ5Ysxr0K1VzbZwwX+Y0o64qQJDthZWbVAoV02oBHKbWzDVI8965HJMyr joboyle@Jamess-MacBook-Pro-2.local"
  }

  display_name = "dbSystem1"

  source_details {
    source_id   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    source_type = "image"
  }

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.db1Subnet.id}"
    assign_public_ip = false
  }
}

resource "oci_core_instance" "dbSystem2" {
  availability_domain = "ToGS:US-ASHBURN-AD-2"
  compartment_id      = "${var.compartment_ocid}"
  shape               = "VM.Standard2.4"

  metadata {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZgJClETAdRFuH4y/uRAgMLuLnn/QL07oZDBEEc9oxCdKCD9nH3GbKykQ+9RP9h29etzOfyDkRF6oB9Dh2ukzhEFcyBIkPVC1Lze1tVjtoXXms3fGpzrYPkq8UxDAwt+k66xuhptR9PSklJspyBEHYAClJN56t4zoRr/ZhJnafZmPQ41QfSWss8JGNiHlqRmlvRLgC/LwRY/q4E1ZE/VfR1RK5eDa6DZOu6UrjTf9fi3BIvoPcLgV7jPW/nFcOiGYSgJ/yq4Dpy8pcfs06DHqR43O4TlWXQ5Ysxr0K1VzbZwwX+Y0o64qQJDthZWbVAoV02oBHKbWzDVI8965HJMyr joboyle@Jamess-MacBook-Pro-2.local"
  }

  display_name = "dbSystem2"

  source_details {
    source_id   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    source_type = "image"
  }

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.db2Subnet.id}"
    assign_public_ip = false
  }
}

//provision bastion instance

resource "oci_core_instance" "bastionInstance" {
  availability_domain = "ToGS:US-ASHBURN-AD-1"
  compartment_id      = "${var.compartment_ocid}"

  source_details {
    source_id   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    source_type = "image"
  }

  shape = "VM.Standard2.4"

  metadata {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZgJClETAdRFuH4y/uRAgMLuLnn/QL07oZDBEEc9oxCdKCD9nH3GbKykQ+9RP9h29etzOfyDkRF6oB9Dh2ukzhEFcyBIkPVC1Lze1tVjtoXXms3fGpzrYPkq8UxDAwt+k66xuhptR9PSklJspyBEHYAClJN56t4zoRr/ZhJnafZmPQ41QfSWss8JGNiHlqRmlvRLgC/LwRY/q4E1ZE/VfR1RK5eDa6DZOu6UrjTf9fi3BIvoPcLgV7jPW/nFcOiGYSgJ/yq4Dpy8pcfs06DHqR43O4TlWXQ5Ysxr0K1VzbZwwX+Y0o64qQJDthZWbVAoV02oBHKbWzDVI8965HJMyr joboyle@Jamess-MacBook-Pro-2.local"
  }

  display_name = "bastionInstance"

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.BastionSubnet.id}"
    assign_public_ip = true
  }
}

resource "oci_core_instance" "webServer1" {
  availability_domain = "ToGS:US-ASHBURN-AD-1"
  compartment_id      = "${var.compartment_ocid}"

  source_details {
    source_id   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    source_type = "image"
  }

  shape = "VM.Standard2.4"

  metadata {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZgJClETAdRFuH4y/uRAgMLuLnn/QL07oZDBEEc9oxCdKCD9nH3GbKykQ+9RP9h29etzOfyDkRF6oB9Dh2ukzhEFcyBIkPVC1Lze1tVjtoXXms3fGpzrYPkq8UxDAwt+k66xuhptR9PSklJspyBEHYAClJN56t4zoRr/ZhJnafZmPQ41QfSWss8JGNiHlqRmlvRLgC/LwRY/q4E1ZE/VfR1RK5eDa6DZOu6UrjTf9fi3BIvoPcLgV7jPW/nFcOiGYSgJ/yq4Dpy8pcfs06DHqR43O4TlWXQ5Ysxr0K1VzbZwwX+Y0o64qQJDthZWbVAoV02oBHKbWzDVI8965HJMyr joboyle@Jamess-MacBook-Pro-2.local"
  }

  display_name = "webServer1"

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.webServerSubnet1.id}"
    assign_public_ip = true
  }
}

resource "oci_core_instance" "webServer2" {
  availability_domain = "ToGS:US-ASHBURN-AD-2"
  compartment_id      = "${var.compartment_ocid}"

  source_details {
    source_id   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    source_type = "image"
  }

  shape = "VM.Standard2.4"

  metadata {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZgJClETAdRFuH4y/uRAgMLuLnn/QL07oZDBEEc9oxCdKCD9nH3GbKykQ+9RP9h29etzOfyDkRF6oB9Dh2ukzhEFcyBIkPVC1Lze1tVjtoXXms3fGpzrYPkq8UxDAwt+k66xuhptR9PSklJspyBEHYAClJN56t4zoRr/ZhJnafZmPQ41QfSWss8JGNiHlqRmlvRLgC/LwRY/q4E1ZE/VfR1RK5eDa6DZOu6UrjTf9fi3BIvoPcLgV7jPW/nFcOiGYSgJ/yq4Dpy8pcfs06DHqR43O4TlWXQ5Ysxr0K1VzbZwwX+Y0o64qQJDthZWbVAoV02oBHKbWzDVI8965HJMyr joboyle@Jamess-MacBook-Pro-2.local"
  }

  display_name = "webServer2"

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.webServerSubnet2.id}"
    assign_public_ip = true
  }
}
