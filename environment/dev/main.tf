module "rgmodule" {
  source = "../../module/VM_module"
  rgname = var.rgnamemodule
  rgloc =  var.rglocmodule
  enable_public_ip = var.enable_public_ip_module
}