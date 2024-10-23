# define variable
variable "rgnamemodule" {
  type = string
}
variable "rglocmodule" {
  type = string
}
variable "submodule" {
  type = map(object({
    address_prefixes = list(string)
  }))
}