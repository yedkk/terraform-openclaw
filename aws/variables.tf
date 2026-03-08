variable "agent_count" {
  type        = number
  description = "Number of OpenClaw agents (1-16). VM size is auto-selected."

  validation {
    condition     = var.agent_count >= 1 && var.agent_count <= 16
    error_message = "agent_count must be between 1 and 16."
  }
}

variable "region" {
  type        = string
  description = "AWS region (default: us-east-1)"
  default     = "us-east-1"
}
