################################################################################
# The first step is to configure the VMware NSX provider to connect to the NSX
# REST API running on the NSX manager.
#
provider "nsxt" {
  host                  = "172.25.18.131"
  username              = "admin"
  password              = "VMware1!VMware1!"
  allow_unverified_ssl  = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

variable "nsx_tag_scope" {
  default = "project"
}

variable "nsx_tag" {
  default = "web"
}


#
data "nsxt_policy_edge_cluster" "demo" {
  display_name = "edgecluster1"
}

data "nsxt_policy_transport_zone" "overlay_tz" {
  display_name = "nsx-overlay-transportzone"
}

#data "nsxt_policy_tier0_gateway" "tier0_gw2" {
#  display_name = "TF-T0-Gateway"
#}

resource "nsxt_policy_tier0_gateway" "tier0_gw1" {
  description              = "Tier-0 provisioned by Terraform"
  display_name             = "TF-T0-Gateway"
  failover_mode            = "PREEMPTIVE"
  default_rule_logging     = false
  enable_firewall          = true
  #force_whitelisting       = false
  ha_mode                  = "ACTIVE_STANDBY"
  internal_transit_subnets = ["102.64.0.0/16"]
  transit_subnets          = ["101.64.0.0/16"]
  edge_cluster_path        = data.nsxt_policy_edge_cluster.demo.path
  rd_admin_address         = "192.168.0.2"

bgp_config {
    local_as_num    = "65101"
    multipath_relax = false

    route_aggregation {
      prefix = "12.10.10.0/24"
    }

}
}
