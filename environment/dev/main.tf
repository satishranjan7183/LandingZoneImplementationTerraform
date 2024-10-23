module "rgmodule" {
  source = "../../module/virtual_machine"
  rgname = var.rgnamemodule
  rgloc = var.rglocmodule
  sub = var.submodule
}