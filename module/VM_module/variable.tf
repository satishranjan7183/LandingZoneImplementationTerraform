variable "rgname" {
 type = string
#   default = "devrg" 
}
variable "rgloc" {
 type = string
#   default = "West Europe" 
}

variable "enable_public_ip" {
  type = bool
#   default = false
}

variable "app_code" {
  type = string
  default = "prodapp"
}

variable "cost_center" {
  type = string
  default = "john_453"
}

variable "environment" {
  type = string
  default = "dev"
}
variable "app_id" {
  type = string
  default = "tea123"
}