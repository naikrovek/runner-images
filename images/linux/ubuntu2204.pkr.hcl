
variable "name_tag" {
  type    = string
  default = "ubuntu-22-full"
}

variable "component" {
  type    = string
  default = "io-de"
}

variable "image_folder" {
  type    = string
  default = "/imagegeneration"
}

variable "imagedata_file" {
  type    = string
  default = "/imagegeneration/imagedata.json"
}

variable "installer_script_folder" {
  type    = string
  default = "/imagegeneration/installers"
}

variable "helper_script_folder" {
  type    = string
  default = "/imagegeneration/helpers"
}

variable "vm_size" {
  type    = string
  default = "c5.large"
}

variable "capture_name_prefix" {
  type    = string
  default = "packer"
}

variable "image_version" {
  type    = string
  default = "dev"
}

variable "image_os" {
  type    = string
  default = "ubuntu22"
}

variable "run_validation_diskspace" {
  type    = string
  default = "false"
}

variable "ubuntu_version" {
  type    = string
  default = "22.04"
}

variable "ubuntu_codename" {
  type    = string
  default = "jammy"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "base_image_account" {
  type    = string
  default = "302414775646"
}

variable "owner_name" {
  type    = string
  default = "io-de"
}

variable "vpc_id" {
  type    = string
  default = "vpc-0386901147f6dd6d5"
}

variable "subnet_id" {
  type    = string
  default = "subnet-05474a997bd444816"
}

variable "security_group_ids" {
  type    = list(string)
  default = ["sg-0d17d3220154b37b7"]
}

variable "dockerhub_login" {
  type    = string
  default = "${env("DOCKERHUB_LOGIN")}"
}

variable "dockerhub_password" {
  type    = string
  default = "${env("DOCKERHUB_PASSWORD")}"
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v4"
}

source "amazon-ebs" "build_vhd" {
  region = var.aws_region
  source_ami_filter {
    filters = {
      name = "Deere_Ubuntu22.04_x64_BaseImage2-202*"
    }
    owners = [var.base_image_account]
    most_recent = true
  }
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    encrypted = "true"
    volume_size = 100
    delete_on_termination = true
    kms_key_id = "d789b256-b44c-4e4d-bdd4-db30f7f5efa1"
  }
  associate_public_ip_address = "false"
  instance_type = var.vm_size
  ssh_username = "ubuntu"
  ami_name = "${var.owner_name}_github-actions-runner_ubuntu22full_{{timestamp}}"
  skip_create_ami = false
  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  security_group_ids = var.security_group_ids
  run_tags = {
    Name = var.name_tag
    component = var.component
  }
  ssh_interface = "private_ip"
}

build {
  sources = ["source.amazon-ebs.build_vhd"]

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["mkdir ${var.image_folder}", "chmod 777 ${var.image_folder}"]
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/apt-mock.sh"
  }

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/base/repos.sh"]
  }

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/base/apt-ubuntu-archive.sh"]
  }

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script           = "${path.root}/scripts/base/apt.sh"
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/limits.sh"
  }

  provisioner "file" {
    destination = "${var.helper_script_folder}"
    source      = "${path.root}/scripts/helpers"
  }

  provisioner "file" {
    destination = "${var.installer_script_folder}"
    source      = "${path.root}/scripts/installers"
  }

  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/post-generation"
  }

  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/tests"
  }

  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/SoftwareReport"
  }

  provisioner "file" {
    destination = "${var.image_folder}/SoftwareReport/"
    source      = "${path.root}/../../helpers/software-report-base"
  }

  provisioner "file" {
    destination = "${var.installer_script_folder}/toolset.json"
    source      = "${path.root}/toolsets/toolset-2204.json"
  }

  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "IMAGEDATA_FILE=${var.imagedata_file}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/preimagedata.sh"]
  }

  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "IMAGE_OS=${var.image_os}", "HELPER_SCRIPTS=${var.helper_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/configure-environment.sh"]
  }

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive", "HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/apt-vital.sh"]
  }

  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/complete-snap-setup.sh", "${path.root}/scripts/installers/powershellcore.sh"]
  }

  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} pwsh -f {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/Install-PowerShellModules.ps1", "${path.root}/scripts/installers/Install-AzureModules.ps1"]
  }

  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = [
                        "${path.root}/scripts/installers/apt-common.sh",
                        "${path.root}/scripts/installers/azcopy.sh",
                        "${path.root}/scripts/installers/azure-cli.sh",
                        "${path.root}/scripts/installers/azure-devops-cli.sh",
                        "${path.root}/scripts/installers/bicep.sh",
                        "${path.root}/scripts/installers/aliyun-cli.sh",
                        "${path.root}/scripts/installers/apache.sh",
                        "${path.root}/scripts/installers/aws.sh",
                        "${path.root}/scripts/installers/clang.sh",
                        "${path.root}/scripts/installers/swift.sh",
                        "${path.root}/scripts/installers/cmake.sh",
                        "${path.root}/scripts/installers/codeql-bundle.sh",
                        "${path.root}/scripts/installers/containers.sh",
                        "${path.root}/scripts/installers/dotnetcore-sdk.sh",
                        "${path.root}/scripts/installers/firefox.sh",
                        "${path.root}/scripts/installers/microsoft-edge.sh",
                        "${path.root}/scripts/installers/gcc.sh",
                        "${path.root}/scripts/installers/gfortran.sh",
                        "${path.root}/scripts/installers/git.sh",
                        "${path.root}/scripts/installers/github-cli.sh",
                        "${path.root}/scripts/installers/google-chrome.sh",
                        "${path.root}/scripts/installers/google-cloud-cli.sh",
                        "${path.root}/scripts/installers/haskell.sh",
                        "${path.root}/scripts/installers/heroku.sh",
                        "${path.root}/scripts/installers/java-tools.sh",
                        "${path.root}/scripts/installers/kubernetes-tools.sh",
                        "${path.root}/scripts/installers/oc.sh",
                        "${path.root}/scripts/installers/leiningen.sh",
                        "${path.root}/scripts/installers/miniconda.sh",
                        "${path.root}/scripts/installers/mono.sh",
                        "${path.root}/scripts/installers/kotlin.sh",
                        "${path.root}/scripts/installers/mysql.sh",
                        "${path.root}/scripts/installers/mssql-cmd-tools.sh",
                        "${path.root}/scripts/installers/sqlpackage.sh",
                        "${path.root}/scripts/installers/nginx.sh",
                        "${path.root}/scripts/installers/nvm.sh",
                        "${path.root}/scripts/installers/nodejs.sh",
                        "${path.root}/scripts/installers/bazel.sh",
                        "${path.root}/scripts/installers/oras-cli.sh",
                        "${path.root}/scripts/installers/php.sh",
                        "${path.root}/scripts/installers/postgresql.sh",
                        "${path.root}/scripts/installers/pulumi.sh",
                        "${path.root}/scripts/installers/ruby.sh",
                        "${path.root}/scripts/installers/r.sh",
                        "${path.root}/scripts/installers/rust.sh",
                        "${path.root}/scripts/installers/julia.sh",
                        "${path.root}/scripts/installers/sbt.sh",
                        "${path.root}/scripts/installers/selenium.sh",
                        "${path.root}/scripts/installers/terraform.sh",
                        "${path.root}/scripts/installers/packer.sh",
                        "${path.root}/scripts/installers/vcpkg.sh",
                        "${path.root}/scripts/installers/dpkg-config.sh",
                        "${path.root}/scripts/installers/yq.sh",
                        "${path.root}/scripts/installers/android.sh",
                        "${path.root}/scripts/installers/pypy.sh",
                        "${path.root}/scripts/installers/python.sh",
                        "${path.root}/scripts/installers/zstd.sh"
                        ]
  }

  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "DOCKERHUB_LOGIN=${var.dockerhub_login}", "DOCKERHUB_PASSWORD=${var.dockerhub_password}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/docker-compose.sh", "${path.root}/scripts/installers/docker.sh"]
  }

  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} pwsh -f {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/Install-Toolset.ps1", "${path.root}/scripts/installers/Configure-Toolset.ps1"]
  }

  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/pipx-packages.sh"]
  }

  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "DEBIAN_FRONTEND=noninteractive", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "/bin/sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/homebrew.sh"]
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/snap.sh"
  }

  provisioner "shell" {
    execute_command   = "/bin/sh -c '{{ .Vars }} {{ .Path }}'"
    expect_disconnect = true
    scripts           = ["${path.root}/scripts/base/reboot.sh"]
  }

  provisioner "shell" {
    execute_command     = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    pause_before        = "1m0s"
    scripts             = ["${path.root}/scripts/installers/cleanup.sh"]
    start_retry_timeout = "10m"
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/apt-mock-remove.sh"
  }

  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    inline           = ["pwsh -File ${var.image_folder}/SoftwareReport/SoftwareReport.Generator.ps1 -OutputDirectory ${var.image_folder}", "pwsh -File ${var.image_folder}/tests/RunAll-Tests.ps1 -OutputDirectory ${var.image_folder}"]
  }

  provisioner "file" {
    destination = "${path.root}/Ubuntu2204-Readme.md"
    direction   = "download"
    source      = "${var.image_folder}/software-report.md"
  }

  provisioner "file" {
    destination = "${path.root}/software-report.json"
    direction   = "download"
    source      = "${var.image_folder}/software-report.json"
  }

  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPT_FOLDER=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "IMAGE_FOLDER=${var.image_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/post-deployment.sh"]
  }

  provisioner "shell" {
    environment_vars = ["RUN_VALIDATION=${var.run_validation_diskspace}"]
    scripts          = ["${path.root}/scripts/installers/validate-disk-space.sh"]
  }

  provisioner "file" {
    destination = "/tmp/"
    source      = "${path.root}/config/ubuntu2204.conf"
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["mkdir -p /etc/vsts", "cp /tmp/ubuntu2204.conf /etc/vsts/machine_instance.conf"]
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["sleep 30", "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"]
  }

}
