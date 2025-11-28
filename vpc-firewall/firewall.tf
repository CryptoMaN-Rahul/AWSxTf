resource "aws_networkfirewall_rule_group" "block_social" {
    capacity = 100
    name     = "block-social-rule-group"
    type     = "STATEFUL"

    rule_group {
      rules_source {
        rules_source_list {
          generated_rules_type = "DENYLIST"
          target_types = ["HTTP_HOST","TLS_SNI"]
          targets = [  "facebook.com", "instagram.com", "tiktok.com"]
        }
      }
    }
  
}


resource "aws_networkfirewall_firewall_policy" "policy" {
    name = "vpc-firewall-policy"
    firewall_policy {
      stateless_default_actions = ["aws:forward_to_sfe" ]
      stateless_fragment_default_actions = ["aws:forward_to_sfe"]

      stateful_rule_group_reference {
        resource_arn = aws_networkfirewall_rule_group.block_social.arn
      }
    }


  
}

resource "aws_networkfirewall_firewall" "main" {
    name="vpc-firewall"
    firewall_policy_arn = aws_networkfirewall_firewall_policy.policy.arn
    vpc_id = aws_vpc.main.id

    subnet_mapping {
      subnet_id=aws_subnet.firewall.id
    }
  
}