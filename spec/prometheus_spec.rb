require 'spec_helper'
require 'aws-sdk'
require 'octopoller'
require 'dotenv'

describe 'prometheus' do
  before(:all) do
    configure_container
    create_env_file
    @docker_entrypoint_output = execute_docker_entrypoint(
        started_indicator: "Server is ready to receive web requests.")
  end

  it "runs prometheus" do
    expect(process('/opt/prometheus/prometheus')).to be_running
  end

  it 'points at the correct configuration file' do
    expect(process('/opt/prometheus/prometheus').args)
        .to(match(/--config\.file \/opt\/prometheus\/prometheus.yml/))
  end

  it 'configures and enables the web UI' do
    args = process('/opt/prometheus/prometheus').args

    expect(args).to(match(
        /--web.console.libraries=\/opt\/prometheus\/console_libraries/))
    expect(args).to(match(
        /--web.console.templates=\/opt\/prometheus\/consoles/))
    expect(args).to(match(
        /--web.enable-admin-api/))
  end

  it 'has some environment' do
    pid = process('/opt/prometheus/prometheus').pid
    environment_contents =
        command("tr '\\0' '\\n' < /proc/#{pid}/environ").stdout
    environment = Dotenv::Parser.call(environment_contents)

    expect(environment).to include('SELF_IP', 'SELF_ID', 'SELF_HOSTNAME')
  end

  def configure_container
    set :backend, :docker
    set :env, {
        'AWS_METADATA_SERVICE_URL' => 'http://metadata:1338',
        'AWS_ACCESS_KEY_ID' => "...",
        'AWS_SECRET_ACCESS_KEY' => "...",
        'AWS_S3_ENDPOINT_URL' => 'http://s3:4566',
        'AWS_S3_BUCKET_REGION' => 'us-east-1',
        'AWS_S3_ENV_FILE_OBJECT_PATH' => 's3://bucket/env-file.env'
    }
    set :docker_image, 'prometheus-aws:latest'
    set :docker_container_create_options, {
        'Entrypoint' => '/bin/sh',
        'HostConfig' => {
            'NetworkMode' => 'docker_prometheus_aws_test_default'
        }
    }
  end

  def create_env_file
    environment = {
        "TESTING" => "123"
    }
    env_file_contents = environment
        .to_a
        .collect { |item| "#{item[0]}=\"#{item[1]}\"" }
        .join("\n")

    command('aws ' +
        '--endpoint-url http://localhost:4566 ' +
        'mb ' +
        's3://bucket ' +
        '--region "us-east-1"')
    command("echo \"#{env_file_contents}\" | " +
        'aws ' +
        '--endpoint-url http://localhost:4566 ' +
        'cp ' +
        '- ' +
        's3://bucket/enf-file.env ' +
        '--region "us-east-1" ' +
        '--sse AES256')
  end

  def execute_docker_entrypoint(opts)
    docker_entrypoint_command =
        command('docker-entrypoint.sh > /tmp/docker-entrypoint.log 2>&1 &')
    exit_status = docker_entrypoint_command.exit_status
    unless exit_status == 0
      raise RuntimeError,
          "docker-entrypoint.sh failed with exit code: #{exit_status}"
    end
    Octopoller.poll(timeout: 15) do
      docker_entrypoint_log = command('cat /tmp/docker-entrypoint.log').stdout
      docker_entrypoint_log =~ /#{opts[:started_indicator]}/ ?
          docker_entrypoint_log :
          :re_poll
    end
  end
end
