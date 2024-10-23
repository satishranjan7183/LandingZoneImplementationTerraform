module "rgmodule" {
  source = "../../module/load_balancer"
  rgname = var.rgnamemodule
  rgloc =  var.rglocmodule
  enable_public_ip = var.enable_public_ip_module
}