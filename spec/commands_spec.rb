# frozen_string_literal: true

require 'spec_helper'

describe 'commands' do
  image = 'prometheus-aws:latest'
  extra = {
    'Entrypoint' => '/bin/sh'
  }

  before(:all) do
    set :backend, :docker
    set :docker_image, image
    set :docker_container_create_options, extra
  end

  after(:all, &:reset_docker_backend)

  it 'includes the prometheus command' do
    expect(command('/opt/prometheus/bin/prometheus --version').stdout)
      .to match(/2.41.0/)
  end

  it 'includes the envsubst command' do
    expect(command('envsubst --version').stdout)
      .to(match(/0.21/))
  end

  def reset_docker_backend
    Specinfra::Backend::Docker.instance.send :cleanup_container
    Specinfra::Backend::Docker.clear
  end
end
