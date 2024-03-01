variable "system_name" {
  type     = string
  nullable = false
}

variable "region" {
  type     = string
  nullable = false
}

variable "slack_incoming_webhooks" {
  type     = list(string)
  nullable = false
}