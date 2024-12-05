terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

resource "docker_network" "jenkins_network" {
  name = "jenkins"
}

resource "docker_volume" "jenkins_data" {
  name = "jenkins-data"
}

resource "docker_volume" "jenkins_docker_certs" {
  name = "jenkins-docker-certs"
}

resource "docker_container" "docker_in_docker" {
  image      = "docker:dind"
  name       = "jenkins-docker"
  rm         = true
  privileged = true
  
  networks_advanced {
    name     = docker_network.jenkins_network.name
    aliases  = ["docker"]  
  }
  
  env = [
    "DOCKER_TLS_CERTDIR=/certs"
  ]
  
  volumes {
    container_path = "/var/jenkins_home"
    volume_name    = docker_volume.jenkins_data.name
  }
  
  volumes {
    container_path = "/certs/client"
    volume_name    = docker_volume.jenkins_docker_certs.name
  }
  
  ports {
    internal = 2376
    external = 2376
  }
}

resource "docker_container" "jenkins_blueocean" {
  image   = "jenkins-custom"
  name    = "jenkins-blueocean"
  restart = "on-failure"
  
  networks_advanced {
    name     = docker_network.jenkins_network.name
    aliases  = ["docker"]  
  }
  
  env = [
    "DOCKER_HOST=tcp://docker:2376", 
    "DOCKER_CERT_PATH=/certs/client",
    "DOCKER_TLS_VERIFY=1"
  ]
  
  ports {
    internal = 8080
    external = 8080
  }
  
  ports {
    internal = 50000
    external = 50000
  }
  
  volumes {
    container_path = "/var/jenkins_home"
    volume_name    = docker_volume.jenkins_data.name
  }
  
  volumes {
    container_path = "/certs/client"
    volume_name    = docker_volume.jenkins_docker_certs.name
    read_only      = true
  }

  depends_on = [docker_container.docker_in_docker]
}
