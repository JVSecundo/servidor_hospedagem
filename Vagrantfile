# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define "hosting-server" do |server|
    server.vm.box = "ubuntu/focal64"
    server.vm.hostname = "hosting-server"
    
    # Recursos
    server.vm.provider "virtualbox" do |vb|
      vb.memory = 4096
      vb.cpus = 2
      vb.name = "hosting-server"
      
      # Otimizações
      vb.customize ["modifyvm", :id, "--cpuexecutioncap", "90"]
    end
    
    # Rede
    server.vm.network "private_network", ip: "192.168.56.10"
    
    # Portas para serviços
    server.vm.network "forwarded_port", guest: 80, host: 8080    # HTTP
    server.vm.network "forwarded_port", guest: 443, host: 8443   # HTTPS
    server.vm.network "forwarded_port", guest: 8080, host: 8081  # Jenkins
    
    # Pastas compartilhadas com paths Windows-friendly
    server.vm.synced_folder "./docker", "/opt/docker"
    
    # Provisionamento
    server.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y docker.io docker-compose
      systemctl enable docker
      systemctl start docker
    SHELL
  end
  
  # Configurações globais
  config.vm.box_check_update = true
  
  # Plugins
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end
end