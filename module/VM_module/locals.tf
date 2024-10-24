locals {
  # common tags
  comman_tags = {
    app_code = var.app_code
    cost_center = var.cost_center
    environment = var.environment
    app_id = var.app_id
  }
# resource spefic tags
rg_tags = {
size = "80"
}
}