terraform {
  backend "gcs" {
    bucket = "terraformJenkins-tfstate"
    auth = "InstancePrincipal"
  }
}
