require 'spec_helper'

describe 'commands' do
  before(:all) do
    set :backend, :docker
    set :env, {
        "AWS_METADATA_SERVICE_URL" => "http://metadata:1338",
        "AWS_S3_ENDPOINT_URL" => "http://s3:4566",
        "AWS_S3_BUCKET_REGION" => "us-east-1",
        "AWS_S3_ENV_FILE_OBJECT_PATH" => "s3://bucket/env-file.env"
    }
    set :docker_image, "prometheus-aws:latest"
    set :docker_container_create_options, {
        "Entrypoint" => "/bin/sh",
        "HostConfig" => {
            "NetworkMode" => "docker_prometheus_aws_test_default"
        }
    }
  end

  ['curl', 'sed', 'bash', 'dumb-init', 'python'].each do |apk|
    it "includes #{apk} system package" do
      expect(package(apk)).to be_installed
    end
  end

  it "includes the AWS CLI" do
    expect(command('aws --version').stderr).to match /1.18.39/
  end

  it "includes s3cmd" do
    expect(command('s3cmd --version').stdout).to match /2.1.0/
  end
end
