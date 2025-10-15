variable "gcp_project_management_id" {
    type = string
    description = "Project id where implement the automation"
}

variable "billing_account_id" {
  type = string
  description = "The billing account ID (ex: 012345-6789AB-CDEF01)"
}

variable "budget_amount" {
  type = number
  description = "The budget value"
  default = 10
}

variable "gcp_region" {
  type        = string
  description = "Resources region"
  default     = "europe-west1"
}