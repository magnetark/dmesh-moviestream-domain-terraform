###############################################################################################
# NOTAS IMPORTANTES
# If we need ti create a dms module for a domain that use kinesis as the entry point for 
# all the events ,we need to be awere of "dms-cloudwatch-logs-role" and "dms-vpc-role" using 
# "https://github.com/terraform-aws-modules/terraform-aws-dms" as a base module, because could
# throw the following error "EntityAlreadyExists".
# 
# This means the base terraform module is not intended for an architecture where we have 
# multiple DMS(module) .nstance,

locals {
  cdc1_name = "moviestream"
  cdc1_dbhost = "moviestream-postgres.cotjbywwuf3z.us-east-1.rds.amazonaws.com"
  cdc1_dbname = "moviestreamdb"
  cdc1_dbuser = "dbpostgresadmin"
  cdc1_dbpass = "CHaNG3m3"
  cdc1_dbport = 5432
  cdc1_dbengine = "postgres"

  tags = {
    module = "dms"
    repository = "https://github.com/terraform-aws-modules/terraform-aws-dms"
  }
}

# ------------------------------------
# POSTGRES MOVIESTREAM REPLICATION [1]
#    name: moviestream-replication

module "database_migration_service" {
  source  = "terraform-aws-modules/dms/aws"

  repl_subnet_group_name        = "${local.cdc1_name}-replication-sunet-group"
  repl_subnet_group_description = "DMS Subnet group for ${local.cdc1_name}"
  repl_subnet_group_subnet_ids  = module.vpc.public_subnets 

  repl_instance_id                           = "${local.cdc1_name}-replication"
  repl_instance_class                        = "dms.t3.small"
  repl_instance_allocated_storage            = 64
  repl_instance_multi_az                     = false
  repl_instance_vpc_security_group_ids       = [aws_security_group.dms_sg.id]
  repl_instance_engine_version               = "3.4.5"
  repl_instance_auto_minor_version_upgrade   = true
  repl_instance_allow_major_version_upgrade  = true
  repl_instance_apply_immediately            = true
  repl_instance_publicly_accessible          = true
  repl_instance_preferred_maintenance_window = "sun:10:30-sun:14:30"

  endpoints = {
    source = {
      endpoint_id                 = "${local.cdc1_name}-endpoint-id" 
      endpoint_type               = "source"
      engine_name                 = local.cdc1_dbengine
      server_name                 = local.cdc1_dbhost
      username                    = local.cdc1_dbuser
      password                    = local.cdc1_dbpass
      port                        = local.cdc1_dbport
      database_name               = local.cdc1_dbname
      extra_connection_attributes = ""
      ssl_mode                    = "none"
      tags                        = { EndpointType = "source" }
    }

    kinesis-target = {
      database_name = "domain-kinesis-taget"
      endpoint_id   = "domain-kinesis-taget"
      endpoint_type = "target"
      engine_name   = "kinesis"

      kinesis_settings = {
        include_control_details        = true
        include_null_and_empty         = true
        include_partition_value        = true
        include_table_alter_operations = true
        include_transaction_details    = true
        message_format                 = "json"
        partition_include_schema_table = true
        service_access_role_arn        = aws_iam_role.dmsrole.arn
        stream_arn                     = aws_kinesis_stream.domain_stream_cdc1.arn
      }
      tags          = { EndpointType = "destination" }
    }
  }

  replication_tasks = {
    cdc_ex = {
      replication_task_id       = "${local.cdc1_name}-replication-task"
      migration_type            = "full-load-and-cdc" # cdc, full-load, full-load-and-cdc
      replication_task_settings = file("./dms-configs/moviestream/settings.json")
      table_mappings            = file("./dms-configs/moviestream/mappings.json")
      source_endpoint_key       = "source"
      target_endpoint_key       = "kinesis-target"
      tags                      = { Task = "PostgreSQL-to-MySQL" }
    }
  }

  #event_subscriptions = {
  #  instance = {
  #    name                             = "instance-events"
  #    enabled                          = true
  #    instance_event_subscription_keys = ["example"]
  #    source_type                      = "replication-instance"
  #    sns_topic_arn                    = "arn:aws:sns:us-east-1:012345678910:example-topic"
  #    event_categories                 = [
  #      "failure",
  #      "creation",
  #      "deletion",
  #      "maintenance",
  #      "failover",
  #      "low storage",
  #      "configuration change"
  #    ]
  #  }
  #  task = {
  #    name                         = "task-events"
  #    enabled                      = true
  #    task_event_subscription_keys = ["cdc_ex"]
  #    source_type                  = "replication-task"
  #    sns_topic_arn                = "arn:aws:sns:us-east-1:012345678910:example-topic"
  #    event_categories             = [
  #      "failure",
  #      "state change",
  #      "creation",
  #      "deletion",
  #      "configuration change"
  #    ]
  #  }
  #}

  tags = merge(var.tags, local.tags, { Name = "vpc_moviestream_domain", Terraform = "true" })
}

# -------------------------------
# <ENGINE> <NAME> REPLICATION [2]
#    name: <NAME>-replication


# -------------------------------
# <ENGINE> <NAME> REPLICATION [3]
#    name: <NAME>-replication