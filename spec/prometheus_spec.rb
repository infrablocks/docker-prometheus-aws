require 'spec_helper'

describe 'prometheus' do
  metadata_service_url = 'http://metadata:1338'
  s3_endpoint_url = 'http://s3:4566'
  s3_bucket_region = 'us-east-1'
  s3_bucket_path = 's3://bucket'
  s3_env_file_object_path = 's3://bucket/env-file.env'

  environment = {
      'AWS_METADATA_SERVICE_URL' => metadata_service_url,
      'AWS_ACCESS_KEY_ID' => "...",
      'AWS_SECRET_ACCESS_KEY' => "...",
      'AWS_S3_ENDPOINT_URL' => s3_endpoint_url,
      'AWS_S3_BUCKET_REGION' => s3_bucket_region,
      'AWS_S3_ENV_FILE_OBJECT_PATH' => s3_env_file_object_path
  }
  image = 'prometheus-aws:latest'
  extra = {
      'Entrypoint' => '/bin/sh',
      'HostConfig' => {
          'NetworkMode' => 'docker_prometheus_aws_test_default'
      }
  }

  before(:all) do
    set :backend, :docker
    set :env, environment
    set :docker_image, image
    set :docker_container_create_options, extra
  end

  describe 'command' do
    after(:all, &:reset_docker_backend)

    it "includes the prometheus command" do
      expect(command('/opt/prometheus/prometheus --version').stderr)
          .to match /2.20.0/
    end
  end

  describe 'entrypoint' do
    before(:all) do
      create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path)

      execute_docker_entrypoint(
          started_indicator: "Server is ready to receive web requests.")
    end

    after(:all, &:reset_docker_backend)

    it "runs prometheus" do
      expect(process('/opt/prometheus/prometheus')).to be_running
    end

    it 'points at the correct configuration file' do
      expect(process('/opt/prometheus/prometheus').args)
          .to(match(/--config\.file=\/opt\/prometheus\/prometheus.yml/))
    end

    it 'configures and enables the web UI' do
      args = process('/opt/prometheus/prometheus').args

      expect(args).to(match(
          /--web.console.libraries=\/opt\/prometheus\/console_libraries/))
      expect(args).to(match(
          /--web.console.templates=\/opt\/prometheus\/consoles/))
    end

    it 'disables the TSDB lockfile' do
      args = process('/opt/prometheus/prometheus').args

      expect(args).to(match(
          /--storage.tsdb.no-lockfile/))
    end

    it 'uses the JSON log format' do
      args = process('/opt/prometheus/prometheus').args

      expect(args).to(match(/--log.format=json/))
    end

    it 'has instance metadata available in its environment' do
      pid = process('/opt/prometheus/prometheus').pid
      environment_contents =
          command("tr '\\0' '\\n' < /proc/#{pid}/environ").stdout
      environment = Dotenv::Parser.call(environment_contents)

      expect(environment)
          .to(include('SELF_IP', 'SELF_ID', 'SELF_HOSTNAME'))
    end
  end

  describe 'prometheus configuration' do
    describe 'without configuration object path provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path)

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'uses the default configuration' do
        prometheus_config = file('/opt/prometheus/prometheus.yml').content

        expect(prometheus_config)
            .to(eq(File.read('spec/fixtures/default-prometheus-config.yml')))
      end
    end

    describe 'with configuration object path provided' do
      before(:all) do
        configuration_file_object_path = "#{s3_bucket_path}/prometheus.yml"

        create_object(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: configuration_file_object_path,
            content: File.read('spec/fixtures/custom-prometheus-config.yml'))
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                "PROMETHEUS_CONFIGURATION_FILE_OBJECT_PATH" =>
                    configuration_file_object_path
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'uses the default configuration' do
        prometheus_config = file('/opt/prometheus/prometheus.yml').content

        expect(prometheus_config)
            .to(eq(File.read('spec/fixtures/custom-prometheus-config.yml')))
      end
    end
  end

  describe 'rules configuration' do
    describe 'without rule file object paths provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path)

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'does not include any rule files' do
        rule_files = command('ls /opt/prometheus/rules').stdout

        expect(rule_files).to(eq(""))
      end
    end

    describe 'with one rule file object path provided' do
      before(:all) do
        rule_file_1_object_path = "#{s3_bucket_path}/rule_file_1.yml"

        create_object(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: rule_file_1_object_path,
            content: File.read('spec/fixtures/rule-file-1.yml'))
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                "PROMETHEUS_RULE_FILE_OBJECT_PATHS" =>
                    "#{rule_file_1_object_path}"
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'fetches the specified rule file' do
        rule_files = command('ls /opt/prometheus/rules').stdout
        rule_file_content =
            command('cat /opt/prometheus/rules/rule_file_1.yml').stdout

        expect(rule_files).to(eq("rule_file_1.yml\n"))
        expect(rule_file_content)
            .to(eq(File.read('spec/fixtures/rule-file-1.yml')))
      end
    end

    describe 'with many rule file object paths provided' do
      before(:all) do
        rule_file_1_object_path = "#{s3_bucket_path}/rule_file_1.yml"
        rule_file_2_object_path = "#{s3_bucket_path}/rule_file_2.yml"

        create_object(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: rule_file_1_object_path,
            content: File.read('spec/fixtures/rule-file-1.yml'))
        create_object(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: rule_file_2_object_path,
            content: File.read('spec/fixtures/rule-file-2.yml'))
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                "PROMETHEUS_RULE_FILE_OBJECT_PATHS" =>
                    "#{rule_file_1_object_path},#{rule_file_2_object_path}"
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'fetches the specified rule files' do
        rule_files = command('ls /opt/prometheus/rules').stdout
        rule_file_1_content =
            command('cat /opt/prometheus/rules/rule_file_1.yml').stdout
        rule_file_2_content =
            command('cat /opt/prometheus/rules/rule_file_2.yml').stdout

        expect(rule_files).to(eq(
            "rule_file_1.yml\n" +
                "rule_file_2.yml\n"))
        expect(rule_file_1_content)
            .to(eq(File.read('spec/fixtures/rule-file-1.yml')))
        expect(rule_file_2_content)
            .to(eq(File.read('spec/fixtures/rule-file-2.yml')))
      end
    end
  end

  describe 'storage' do
    describe 'without tsdb storage location provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path)

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'stores tsdb in /var/lib/prometheus' do
        expect(process('/opt/prometheus/prometheus').args)
            .to(match(/--storage\.tsdb\.path=\/var\/lib\/prometheus/))
      end
    end

    describe 'with tsdb storage location provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                "PROMETHEUS_STORAGE_TSDB_PATH" => "/data"
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'stores tsdb in /var/lib/prometheus' do
        expect(process('/opt/prometheus/prometheus').args)
            .to(match(/--storage\.tsdb\.path=\/data/))
      end
    end

    describe 'without tsdb storage retention provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path)

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'retains samples for 30 days' do
        expect(process('/opt/prometheus/prometheus').args)
            .to(match(/--storage\.tsdb\.retention\.time=30d/))
      end
    end

    describe 'with tsdb storage retention provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                "PROMETHEUS_STORAGE_TSDB_RETENTION_TIME" => "10d"
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'retains samples for the specified duration' do
        expect(process('/opt/prometheus/prometheus').args)
            .to(match(/--storage\.tsdb\.retention\.time=10d/))
      end
    end
  end

  describe 'console' do
    describe 'without external URL provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path)

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'does not include the external URL flag' do
        expect(process('/opt/prometheus/prometheus').args)
            .not_to(match(/--web.external-url/))
      end
    end

    describe 'with external URL provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                'PROMETHEUS_WEB_EXTERNAL_URL' =>
                    'https://prometheus.example.com'
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'uses the specified external URL' do
        expect(process('/opt/prometheus/prometheus').args)
            .to(match(/--web.external-url=https:\/\/prometheus.example.com/))
      end
    end
  end

  describe 'admin API' do
    describe 'without enable admin API flag provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path)

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'does not include the enable admin API flag' do
        expect(process('/opt/prometheus/prometheus').args)
            .not_to(match(/--web.enable-admin-api/))
      end
    end

    describe 'with enable admin API flag provided and true' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                "PROMETHEUS_WEB_ENABLE_ADMIN_API" => "true"
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'includes the enable admin API flag' do
        expect(process('/opt/prometheus/prometheus').args)
            .to(match(/--web.enable-admin-api/))
      end
    end

    describe 'with enable admin API flag provided and not true' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                "PROMETHEUS_WEB_ENABLE_ADMIN_API" => "false"
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'does not include the enable admin API flag' do
        expect(process('/opt/prometheus/prometheus').args)
            .not_to(match(/--web.enable-admin-api/))
      end
    end
  end

  describe 'lifecycle' do
    describe 'without enable lifecycle flag provided' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path)

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'does not include the enable lifecycle flag' do
        expect(process('/opt/prometheus/prometheus').args)
            .not_to(match(/--web.enable-lifecycle/))
      end
    end

    describe 'with enable lifecycle flag provided and true' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                "PROMETHEUS_WEB_ENABLE_LIFECYCLE" => "true"
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'includes the enable lifecycle flag' do
        expect(process('/opt/prometheus/prometheus').args)
            .to(match(/--web.enable-lifecycle/))
      end
    end

    describe 'with enable lifecycle flag provided and not true' do
      before(:all) do
        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: {
                "PROMETHEUS_WEB_ENABLE_LIFECYCLE" => "false"
            })

        execute_docker_entrypoint(
            started_indicator: "Server is ready to receive web requests.")
      end

      after(:all, &:reset_docker_backend)

      it 'does not include the enable lifecycle flag' do
        expect(process('/opt/prometheus/prometheus').args)
            .not_to(match(/--web.enable-lifecycle/))
      end
    end
  end

  def reset_docker_backend
    Specinfra::Backend::Docker.instance.send :cleanup_container
    Specinfra::Backend::Docker.clear
  end

  def create_env_file(opts)
    create_object(opts
        .merge(content: (opts[:env] || {})
            .to_a
            .collect { |item| " #{item[0]}=\"#{item[1]}\"" }
            .join("\n")))
  end

  def execute_command(command_string)
    command = command(command_string)
    exit_status = command.exit_status
    unless exit_status == 0
      raise RuntimeError,
          "\"#{command_string}\" failed with exit code: #{exit_status}"
    end
    command
  end

  def create_object(opts)
    execute_command('aws ' +
        "--endpoint-url #{opts[:endpoint_url]} " +
        's3 ' +
        'mb ' +
        "#{opts[:bucket_path]} " +
        "--region \"#{opts[:region]}\"")
    execute_command("echo -n #{Shellwords.escape(opts[:content])} | " +
        'aws ' +
        "--endpoint-url #{opts[:endpoint_url]} " +
        's3 ' +
        'cp ' +
        '- ' +
        "#{opts[:object_path]} " +
        "--region \"#{opts[:region]}\" " +
        '--sse AES256')
  end

  def execute_docker_entrypoint(opts)
    logfile_path = '/tmp/docker-entrypoint.log'

    execute_command(
        "docker-entrypoint.sh > #{logfile_path} 2>&1 &")

    begin
      Octopoller.poll(timeout: 5) do
        docker_entrypoint_log = command("cat #{logfile_path}").stdout
        docker_entrypoint_log =~ /#{opts[:started_indicator]}/ ?
            docker_entrypoint_log :
            :re_poll
      end
    rescue Octopoller::TimeoutError => e
      puts command("cat #{logfile_path}").stdout
      raise e
    end
  end
end
