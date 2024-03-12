module "prod" {
    source = "../modules/blog"

    environment = {name = "prod"
                   network_prefix = "10.1"
    }

    min_size = 1
    max_size = 5
}