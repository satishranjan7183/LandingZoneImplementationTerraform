# define variable
variable "rgname" {
  type = string
}
variable "rgloc" {
  type = string
}
variable "sub" {
  type = map(object({
    address_prefixes = list(string)
  }))
}
