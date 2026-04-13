locals {
  tags = merge(
    {
      environment = var.environment
      managed-by  = "terraform"
      pattern     = "hub-spoke"
    },
    var.tags
  )
}
