# Hourly snapshots and advanced retention for every share agent-bot can write to.
#
# DSM has no documented API for this. The calls below were captured from the
# Snapshot Replication UI (DSM 7.3.2, Snapshot Replication 7.4.7) and replayed
# with the provider's generic synology_api resource.
#
# Two quirks drive the design:
#   1. set_schedule with task_id = -1 always creates a NEW scheduled task, even
#      if the share already has one. Passing the existing task_id updates it in
#      place. So each share first reads its current task_id (get_schedule) and
#      passes it to set_schedule.
#   2. synology_api only calls DSM on create/update and never refreshes. The
#      get_schedule read is replaced whenever the share's settings change, so
#      the task_id it feeds to set_schedule is always current.
#
# synology_api can't detect changes made in the DSM UI. Change these settings
# here, not in Snapshot Replication.

locals {
  # DSM retention bitmask: 1 = minimum, 2 = hourly, 4 = daily, 8 = weekly.
  adv_policy_type = 1 + 2 + 4 + 8

  schedule = {
    for share, minute in var.shares : share => jsonencode({
      date_type      = 0
      week_name      = "0,1,2,3,4,5,6"
      hour           = 0
      min            = minute
      repeat_hour    = 1
      repeat_min     = 0
      last_work_hour = 23
    })
  }
}

# Changes whenever a share's schedule or the retention policy changes.
resource "terraform_data" "settings" {
  for_each = var.shares
  input    = sha256(jsonencode([local.schedule[each.key], var.retention]))
}

# Read-only: the share's current snapshot task ID (-1 if it has none).
resource "synology_api" "current_schedule" {
  for_each = var.shares

  api     = "SYNO.Core.Share.Snapshot"
  method  = "get_schedule"
  version = 1
  parameters = {
    name = each.key
  }

  lifecycle {
    replace_triggered_by = [terraform_data.settings[each.key]]
  }
}

resource "synology_api" "schedule" {
  for_each = var.shares

  api     = "SYNO.Core.Share.Snapshot"
  method  = "set_schedule"
  version = 1
  parameters = {
    name                     = each.key
    enable_snapshot_schedule = "true"
    schedule                 = local.schedule[each.key]
    task_id                  = tostring(synology_api.current_schedule[each.key].result.task_id)
  }
}

resource "synology_api" "retention" {
  for_each = var.shares

  api     = "SYNO.DisasterRecovery.Retention"
  method  = "set"
  version = 1
  parameters = {
    type          = "Share" # Capital S. Lowercase silently reads/writes a default record.
    name          = each.key
    policyType    = "128" # Advanced retention
    advPolicyType = tostring(local.adv_policy_type)
    advHourly     = tostring(var.retention.hourly)
    advDaily      = tostring(var.retention.daily)
    advWeekly     = tostring(var.retention.weekly)
    advMonthly    = "1"
    advYearly     = "0"
    advMinimum    = tostring(var.retention.minimum)
    advRetainDay  = "1"
    retainDay     = "7"
    recently      = "64"
    tid           = "-1"
  }

  depends_on = [synology_api.schedule]
}

# Read back what DSM stored, for checking in the run output.
output "task_ids" {
  value = { for k, v in synology_api.current_schedule : k => v.result.task_id }
}
