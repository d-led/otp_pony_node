Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"

  config.vm.synced_folder ".", "/vagrant"

  # config.vm.provider "virtualbox" do |vb|
  #   vb.memory = "1024"
  # end

  config.vm.provision "shell", privileged: true, path: "./travis_install.sh"

  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    echo cd /vagrant >> `pwd`/.profile
  SHELL
end
