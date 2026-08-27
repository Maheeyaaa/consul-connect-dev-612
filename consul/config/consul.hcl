datacenter = "dev"

data_dir = "/consul/data"

server = true

bootstrap_expect = 1

ui_config {
  enabled = true
}

bind_addr = "0.0.0.0"

client_addr = "0.0.0.0"

ports {
  http = 8500
  grpc = 8502
  grpc_tls = 8503
  dns = 8600
}

