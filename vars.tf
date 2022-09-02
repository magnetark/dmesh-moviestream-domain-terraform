variable "dominio" {
    description = "domain name"
}

variable "tags" {
  description = ""
  type        = map(any)
  default     = {}
}