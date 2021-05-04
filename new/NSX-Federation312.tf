
provider "nsxt" {
  host                 = "172.24.17.155"
  username             = "admin"
  password             = "VMware1!VMware1!"
  global_manager       = "true"
  allow_unverified_ssl = true
}

provider "nsxt" {
  alias                = "virginia"
  host                 = "172.24.19.230"
  username             = "admin"
  password             = "VMware1!VMware1!2"
  allow_unverified_ssl = true
}

/*
provider "nsxt" {
  alias                = "dallas"
  host                 = "172.25.18.167"
  username             = "admin"
  password             = "VMware1!VMware1!"
  allow_unverified_ssl = true
}
*/

data "nsxt_policy_site" "virginia" {
  display_name = "virginia"
}

data "nsxt_policy_site" "dallas" {
  display_name = "dallas"
}

data "nsxt_policy_transport_zone" "virginia_overlay_tz" {
  display_name = "nsx-overlay-transportzone"
  site_path    = data.nsxt_policy_site.virginia.path
}

data "nsxt_policy_transport_zone" "dallas_overlay_tz" {
  display_name = "nsx-overlay-transportzone"
  site_path    = data.nsxt_policy_site.dallas.path
}

data "nsxt_policy_edge_cluster" "virginia" {
  display_name = "Edge-Cluster"
  site_path    = data.nsxt_policy_site.virginia.path
}

data "nsxt_policy_edge_cluster" "dallas" {
  display_name = "Edge-Cluster"
  site_path    = data.nsxt_policy_site.dallas.path
}

data "nsxt_policy_edge_node" "virginia_edge1" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.virginia.path
  member_index      = 0
}

resource "nsxt_policy_tier0_gateway" "global_t0" {
  display_name  = "Global-T0"
  nsx_id        = "Global-T0"
  description   = "Tier-0 with Global scope"
  failover_mode = "PREEMPTIVE"
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.dallas.path
  }
  locale_service {
    edge_cluster_path    = data.nsxt_policy_edge_cluster.virginia.path
    preferred_edge_paths = [data.nsxt_policy_edge_node.virginia_edge1.path]
  }
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.dallas.path
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_bgp_config" "global_bgp_t0" {
  site_path             = data.nsxt_policy_site.dallas.path
  gateway_path          = nsxt_policy_tier0_gateway.global_t0.path
  enabled               = true
  inter_sr_ibgp         = true
  local_as_num          = 60001
  graceful_restart_mode = "HELPER_ONLY"
  route_aggregation {
    prefix       = "20.1.0.0/24"
    summary_only = false
  }
}

resource "nsxt_policy_tier1_gateway" "virginia_t1" {
  display_name = "Virginia-T1"
  nsx_id       = "Virginia-T1"
  tier0_path   = nsxt_policy_tier0_gateway.global_t0.path
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.virginia.path
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_tier1_gateway" "dallas_t1" {
  display_name = "Dallas-T1"
  nsx_id       = "Dallas-T1"
  tier0_path   = nsxt_policy_tier0_gateway.global_t0.path
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.dallas.path
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_tier1_gateway" "virginia_dallas_t1" {
  display_name = "Virginia-Dallas-T1"
  nsx_id       = "Virginia-Dallas-T1"
  tier0_path   = nsxt_policy_tier0_gateway.global_t0.path
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.virginia.path
  }
  locale_service {
    edge_cluster_path = data.nsxt_policy_edge_cluster.dallas.path
  }
  intersite_config {
    primary_site_path = data.nsxt_policy_site.virginia.path
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_tier1_gateway" "global_t1" {
  display_name = "Global-T1"
  nsx_id       = "Global-T1"
  tier0_path   = nsxt_policy_tier0_gateway.global_t0.path
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_segment" "global_segment" {
  display_name      = "Global-Segment"
  nsx_id            = "Global-Segment"
  connectivity_path = nsxt_policy_tier1_gateway.global_t1.path
  subnet {
    cidr = "40.40.40.1/24"
  }
  advanced_config {
    connectivity = "ON"
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_segment" "virginia_segment" {
  display_name        = "Virginia-Segment"
  nsx_id              = "Virginia-Segment"
  connectivity_path   = nsxt_policy_tier1_gateway.virginia_t1.path
  transport_zone_path = data.nsxt_policy_transport_zone.virginia_overlay_tz.path
  subnet {
    cidr = "41.41.41.1/24"
  }
  advanced_config {
    connectivity = "ON"
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_segment" "dallas_segment" {
  display_name        = "Dallas-Segment"
  nsx_id              = "Dallas-Segment"
  connectivity_path   = nsxt_policy_tier1_gateway.dallas_t1.path
  transport_zone_path = data.nsxt_policy_transport_zone.dallas_overlay_tz.path
  subnet {
    cidr = "42.42.42.1/24"
  }
  advanced_config {
    connectivity = "ON"
  }
  tag {
    tag = "terraform"
  }
}

data "nsxt_policy_service" "ssh" {
  display_name = "SSH"
}

data "nsxt_policy_service" "icmp" {
  display_name = "ICMP ALL"
}

resource "nsxt_policy_group" "virginia_group" {
  display_name = "virginia-group"
  nsx_id       = "virginia-group"
  domain       = data.nsxt_policy_site.virginia.id
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "virginia"
    }
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_group" "dallas_group" {
  display_name = "dallas-group"
  nsx_id       = "dallas-group"
  domain       = data.nsxt_policy_site.dallas.id
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "dallas"
    }
  }
  tag {
    tag = "terraform"
  }
}

resource "nsxt_policy_security_policy" "virginia-dallas-policy" {
  display_name = "Virginia-Dallas-SSH"
  nsx_id       = "Virginia-Dallas-SSH"
  category     = "Application"
  stateful     = true
  rule {
    display_name       = "Virginia-Dallas-SSH"
    source_groups      = [nsxt_policy_group.virginia_group.path]
    destination_groups = [nsxt_policy_group.dallas_group.path]
    services           = [data.nsxt_policy_service.ssh.path]
    action             = "ALLOW"
  }
  rule {
    display_name       = "Dallas-Virginia-SSH"
    source_groups      = [nsxt_policy_group.dallas_group.path]
    destination_groups = [nsxt_policy_group.virginia_group.path]
    services           = [data.nsxt_policy_service.ssh.path]
    action             = "ALLOW"
  }
  }
