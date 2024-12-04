terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {
  host = "npipe:////.//pipe//docker_engine"
}

# Crear red 
resource "docker_network" "jenkins_network" {
  name = "jenkins"
}

resource "docker_container" "jenkins" {
  name  = "jenkins-blueocean"
  image = "jenkins-custom"  # imagen personalizada

  restart = "on-failure"  

  network_mode = docker_network.jenkins_network.name


  ports {
    internal = 8080
    external = 8080
  }

  ports {
    internal = 50000
    external = 50000
  }

  # Volumen persistente para los datos de Jenkins
  volumes {
    container_path = "/var/jenkins_home"
    read_only      = false
  }

  privileged = true

}

resource "docker_container" "docker_in_docker" {
  name  = "docker_in_docker"
  image = "docker:20.10.12-dind"
  privileged = true
  ports {
    internal = 2375
    external = 2375
  }
  network_mode = docker_network.jenkins_network.name
  env = [
    "DOCKER_TLS_CERTDIR="  
  ]
}
