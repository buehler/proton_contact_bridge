data "external_schema" "gorm" {
  program = [
    "go",
    "run",
    "-mod=mod",
    "ariga.io/atlas-provider-gorm",
    "load",
    "--path", "./database/models",
    "--dialect", "sqlite", // | postgres | sqlite | sqlserver
  ]
}
env "gorm" {
  src = data.external_schema.gorm.url
  dev = "sqlite://dev?mode=memory"
  migration {
    dir = "file://./database/migrations?format=goose"
  }
  format {
    migrate {
      diff = "{{ sql . \"  \" }}"
    }
  }
}
