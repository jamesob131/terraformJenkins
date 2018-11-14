variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "compartment_ocid" {}
variable "region" {}

# Configure the Oracle Cloud Infrastructure provider to use Instance Principal based authentication
provider "oci" {
  auth             = "InstancePrincipal"
  region           = "us-ashburn-1"
}

resource "oci_core_virtual_network" "VCN" {
  cidr_block     = "10.0.0.0/16"
  dns_label      = "VCN"
  #compartment_id = "${var.compartment_ocid}"
  display_name   = "VCN"
}

//Creating Internet and NAT gateways
resource "oci_core_internet_gateway" "IGW" {
  #compartment_id = "${var.compartment_ocid}"
  display_name   = "IGW"
  enabled        = true
  vcn_id         = "${oci_core_virtual_network.VCN.id}"
}

resource "oci_core_nat_gateway" "nat_gateway" {
  #compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.VCN.id}"
  display_name   = "nat_gateway"
}

//create two route tables
resource "oci_core_route_table" "PublicSubnetRT" {
  #compartment_id = "${var.compartment_ocid}"
  display_name   = "PublicSubnetRT"
  vcn_id         = "${oci_core_virtual_network.VCN.id}"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.IGW.id}"
  }
}

resource "oci_core_route_table" "PrivateSubnetRT" {
  #compartment_id = "${var.compartment_ocid}"
  display_name   = "PrivateSubnetRT"
  vcn_id         = "${oci_core_virtual_network.VCN.id}"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = "${oci_core_nat_gateway.nat_gateway.id}"
  }
}

//create securitylists for each subnet (bastion subnet, private db1 subnet, private db2 subnet)
resource "oci_core_security_list" "BastionSecurityList" {
  #compartment_id = "${var.compartment_ocid}"
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
  #compartment_id = "${var.compartment_ocid}"
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
  #compartment_id = "${var.compartment_ocid}"
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

//create 3 subnets

resource "oci_core_subnet" "BastionSubnet" {
  availability_domain        = "IFqY:US-ASHBURN-AD-1"
  cidr_block                 = "10.0.0.0/24"
  #compartment_id             = "${var.compartment_ocid}"
  display_name               = "BastionSubnet"
  dns_label                  = "bastionDNS"
  vcn_id                     = "${oci_core_virtual_network.VCN.id}"
  prohibit_public_ip_on_vnic = false
  route_table_id             = "${oci_core_route_table.PublicSubnetRT.id}"

  security_list_ids = [
    "${oci_core_security_list.BastionSecurityList.id}",
  ]
}

resource "oci_core_subnet" "db1Subnet" {
  availability_domain        = "IFqY:US-ASHBURN-AD-1"
  cidr_block                 = "10.0.1.0/24"
  #compartment_id             = "${var.compartment_ocid}"
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
  availability_domain        = "IFqY:US-ASHBURN-AD-2"
  cidr_block                 = "10.0.2.0/24"
  #compartment_id             = "${var.compartment_ocid}"
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

resource "oci_database_db_system" "dbSystem1" {
  #Required
  availability_domain = "IFqY:US-ASHBURN-AD-1"
  #compartment_id      = "${var.compartment_ocid}"
  database_edition    = "ENTERPRISE_EDITION_EXTREME_PERFORMANCE"

  db_home {
    #Required
    database {
      #Required
      admin_password = "PAssw0rd1_-"

      db_name  = "db1"
      pdb_name = "pdb1"
    }

    #Optional
    db_version = "18.2.0.0"
  }

  hostname        = "db1"
  shape           = "VM.Standard2.1"
  ssh_public_keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDb7Bo5JCc/w8MvUtL7vTchErWg0eK3ukKEKEr7aAoLyW6K9GYvh+IL/1/1YTagj9rUtEVbjqFLu1TTkvoDiAw+rt6QWhJ6YqmgztvlGWC5P+VOL8aSBxKfGI3b3wNRrnpjCNZ9AeE6oepcM7F5sTUyxzXZyxbe7ei9aaBdyD11KKxqGsgThGb24qQA+n+G2MstWOr6IjbWTTzwtlVqNIudGVZnCmPZZD1kRmaHpH/DZwnc4BGNCUxUvdcfO8yz/kfVuQLwrq9GvCkThCdrtOc2pZeT3ygF6aOixLhgjZDqj9Fd1lVhVKTQdwsue9z/RlVWL2NYYD8ckM4iM6LVHQa1 sdahal@dhcp-10-10-235-187.usdhcp.oraclecorp.com"]
  subnet_id       = "${oci_core_subnet.db1Subnet.id}"

  #Optional

  data_storage_size_in_gb = "256"
  display_name = "dbSystem1"
  node_count   = 1
}

resource "oci_database_db_system" "dbSystem2" {
  #Required
  availability_domain = "IFqY:US-ASHBURN-AD-2"
  #compartment_id      = "${var.compartment_ocid}"
  database_edition    = "ENTERPRISE_EDITION_EXTREME_PERFORMANCE"

  db_home {
    #Required
    database {
      #Required
      admin_password = "PAssw0rd1_-"

      db_name  = "db2"
      pdb_name = "pdb2"
    }

    #Optional
    db_version = "18.2.0.0"
  }

  hostname        = "db2"
  shape           = "VM.Standard2.1"
  ssh_public_keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDb7Bo5JCc/w8MvUtL7vTchErWg0eK3ukKEKEr7aAoLyW6K9GYvh+IL/1/1YTagj9rUtEVbjqFLu1TTkvoDiAw+rt6QWhJ6YqmgztvlGWC5P+VOL8aSBxKfGI3b3wNRrnpjCNZ9AeE6oepcM7F5sTUyxzXZyxbe7ei9aaBdyD11KKxqGsgThGb24qQA+n+G2MstWOr6IjbWTTzwtlVqNIudGVZnCmPZZD1kRmaHpH/DZwnc4BGNCUxUvdcfO8yz/kfVuQLwrq9GvCkThCdrtOc2pZeT3ygF6aOixLhgjZDqj9Fd1lVhVKTQdwsue9z/RlVWL2NYYD8ckM4iM6LVHQa1 sdahal@dhcp-10-10-235-187.usdhcp.oraclecorp.com"]
  subnet_id       = "${oci_core_subnet.db2Subnet.id}"

  #Optional

  data_storage_size_in_gb = "256"
  display_name = "dbSystem2"
  node_count   = 1
}

//provision bastion instance

resource "oci_core_instance" "bastionInstance" {
  availability_domain = "IFqY:US-ASHBURN-AD-1"
  #compartment_id      = "${var.compartment_ocid}"

  source_details {
    source_id   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    source_type = "image"
  }

  shape = "VM.Standard2.1"

  metadata {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDb7Bo5JCc/w8MvUtL7vTchErWg0eK3ukKEKEr7aAoLyW6K9GYvh+IL/1/1YTagj9rUtEVbjqFLu1TTkvoDiAw+rt6QWhJ6YqmgztvlGWC5P+VOL8aSBxKfGI3b3wNRrnpjCNZ9AeE6oepcM7F5sTUyxzXZyxbe7ei9aaBdyD11KKxqGsgThGb24qQA+n+G2MstWOr6IjbWTTzwtlVqNIudGVZnCmPZZD1kRmaHpH/DZwnc4BGNCUxUvdcfO8yz/kfVuQLwrq9GvCkThCdrtOc2pZeT3ygF6aOixLhgjZDqj9Fd1lVhVKTQdwsue9z/RlVWL2NYYD8ckM4iM6LVHQa1 sdahal@dhcp-10-10-235-187.usdhcp.oraclecorp.com"
  }

  display_name = "bastionInstance"

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.BastionSubnet.id}"
    assign_public_ip = true
  }
}

//configure bastion instance


//configure db1 to have dataguard


//configure db2 to have dataguard

