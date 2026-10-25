variable "shares" {
  description = "Shared folders to snapshot, mapped to the minute past the hour their snapshot runs. Minutes are staggered so snapshots don't all start at once."
  type        = map(number)
  default = {
    "vault-personal"  = 0
    "docs"            = 5
    "photo"           = 10
    "picture_storage" = 15
    "git"             = 20
    "vault-work"      = 25
    "homes"           = 30
    "movies"          = 35
    "NetBackup"       = 40
    "Plex"            = 45
    "PlexMediaServer" = 50
    "tv_shows"        = 55
  }
}

variable "retention" {
  description = "Advanced retention: keep the latest snapshot of each hour/day/week for this many hours/days/weeks, and never fewer than `minimum` snapshots."
  type = object({
    hourly  = number
    daily   = number
    weekly  = number
    minimum = number
  })
  default = {
    hourly  = 24
    daily   = 30
    weekly  = 12
    minimum = 5
  }
}

variable "revision" {
  description = "Bump to re-send every call to DSM even when nothing else changed. The API calls are blind, so this is the way to repeat them."
  type        = number
  default     = 2
}
