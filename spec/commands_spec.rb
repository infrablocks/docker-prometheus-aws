require 'spec_helper'

describe 'commands' do
  image = 'prometheus-aws:latest'
  extra = {
      'Entrypoint' => '/bin/sh',
  }

  before(:all) do
    set :backend, :docker
    set :docker_image, image
    set :docker_container_create_options, extra
  end

  after(:all, &:reset_docker_backend)

  it "includes the prometheus command" do
    expect(command('/opt/prometheus/bin/prometheus --version').stderr)
        .to match /2.22.0/
  end

  it 'includes the envsubst command' do
    expect(command('envsubst --version').stdout)
        .to(match(/0.20.2/))
  end

  def reset_docker_backend
    Specinfra::Backend::Docker.instance.send :cleanup_container
    Specinfra::Backend::Docker.clear
  end
end
