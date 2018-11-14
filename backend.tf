terraform {
  backend "gcs" {
    bucket = "<your-project-id>-tfstate"
    auth = "InstancePrincipal"
  }
}
