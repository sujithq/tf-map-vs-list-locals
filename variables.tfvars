resource_groups = [
  {
    name     = "Terraform1"
    location = "eastus2" //Azure Region to use
    tags = {
      created_by = "xxx.xxx"
      contact_dl = "xxx.xxx@xyz.com"
      env        = "dev"
    }
    test = "bqsl"
  },
  {
    name     = "Terraform2"
    location = "eastus2" //Azure Region to use
    tags = {
      created_by = "yyy.yyy"
      contact_dl = "yyy.yyy@xyz.com"
      env        = "nprd"
    }
  }
]