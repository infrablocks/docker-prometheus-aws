# frozen_string_literal: true

require 'spec_helper'

describe 'entrypoint' do
  def metadata_service_url
    'http://metadata:1338'
  end

  def s3_endpoint_url
    'http://s3:4566'
  end

  def s3_bucket_region
    'us-east-1'
  end

  def s3_bucket_path
    's3://bucket'
  end

  def s3_env_file_object_path
    's3://bucket/env-file.env'
  end

  def environment
    {
      'AWS_METADATA_SERVICE_URL' => metadata_service_url,
      'AWS_ACCESS_KEY_ID' => '...',
      'AWS_SECRET_ACCESS_KEY' => '...',
      'AWS_S3_ENDPOINT_URL' => s3_endpoint_url,
      'AWS_S3_BUCKET_REGION' => s3_bucket_region,
      'AWS_S3_ENV_FILE_OBJECT_PATH' => s3_env_file_object_path
    }
  end

  def image
    'prometheus-aws:latest'
  end

  def extra
    {
      'Entrypoint' => '/bin/sh',
      'HostConfig' => {
        'NetworkMode' => 'docker_prometheus_aws_test_default'
      }
    }
  end

  before(:all) do
    set :backend, :docker
    set :env, environment
    set :docker_image, image
    set :docker_container_create_options, extra
  end

  describe 'by default' do
    before(:all) do
      create_env_file(
        endpoint_url: s3_endpoint_url,
        region: s3_bucket_region,
        bucket_path: s3_bucket_path,
        object_path: s3_env_file_object_path
      )

      execute_docker_entrypoint(
        started_indicator: 'Server is ready to receive web requests.'
      )
    end

    after(:all, &:reset_docker_backend)

    it 'runs prometheus' do
      expect(process('/opt/prometheus/bin/prometheus')).to be_running
    end

    it 'points at the correct configuration file' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .to(match(%r{--config\.file=/opt/prometheus/conf/prometheus.yml}))
    end

    it 'uses the JSON log format' do
      args = process('/opt/prometheus/bin/prometheus').args

      expect(args).to(match(/--log.format=json/))
    end

    it 'uses the default prometheus configuration' do
      prometheus_config = file('/opt/prometheus/conf/prometheus.yml').content

      expect(prometheus_config)
        .to(eq(File.read('spec/fixtures/default-prometheus-config.yml')))
    end

    it 'does not include any rule files' do
      rule_files = command('ls /opt/prometheus/conf/rules').stdout

      expect(rule_files).to(eq(''))
    end

    it 'stores tsdb in /var/opt/prometheus' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .to(match(%r{--storage\.tsdb\.path=/var/opt/prometheus}))
    end

    it 'retains samples for 30 days' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .to(match(/--storage\.tsdb\.retention\.time=30d/))
    end

    it 'does not specify a TSDB minimum block duration' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .not_to(match(/--storage\.tsdb\.min-block-duration/))
    end

    it 'does not specify a TSDB maximum block duration' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .not_to(match(/--storage\.tsdb\.max-block-duration/))
    end

    it 'disables the TSDB lockfile' do
      args = process('/opt/prometheus/bin/prometheus').args

      expect(args).to(match(
                        /--storage.tsdb.no-lockfile/
                      ))
    end

    it 'configures and enables the web UI' do
      args = process('/opt/prometheus/bin/prometheus').args

      expect(args)
        .to(
          match(%r{--web.console.libraries=/opt/prometheus/console_libraries})
            .and(match(%r{--web.console.templates=/opt/prometheus/consoles}))
        )
    end

    it 'does not include the external URL flag' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .not_to(match(/--web.external-url/))
    end

    it 'does not include the enable admin API flag' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .not_to(match(/--web.enable-admin-api/))
    end

    it 'does not include the enable lifecycle flag' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .not_to(match(/--web.enable-lifecycle/))
    end

    it 'has self IP available in its environment' do
      pid = process('/opt/prometheus/bin/prometheus').pid
      environment_contents =
        command("tr '\\0' '\\n' < /proc/#{pid}/environ").stdout

      expect(environment_contents).to(match(/^SELF_IP/))
    end

    it 'has self ID available in its environment' do
      pid = process('/opt/prometheus/bin/prometheus').pid
      environment_contents =
        command("tr '\\0' '\\n' < /proc/#{pid}/environ").stdout

      expect(environment_contents).to(match(/^SELF_ID/))
    end

    it 'has self hostname available in its environment' do
      pid = process('/opt/prometheus/bin/prometheus').pid
      environment_contents =
        command("tr '\\0' '\\n' < /proc/#{pid}/environ").stdout

      expect(environment_contents).to(match(/^SELF_HOSTNAME/))
    end

    it 'has self availability zone available in its environment' do
      pid = process('/opt/prometheus/bin/prometheus').pid
      environment_contents =
        command("tr '\\0' '\\n' < /proc/#{pid}/environ").stdout

      expect(environment_contents).to(match(/^SELF_AVAILABILITY_ZONE/))
    end
  end

  describe 'with prometheus configuration' do
    describe 'with configuration object path provided' do
      before(:all) do
        configuration_file_object_path = "#{s3_bucket_path}/prometheus.yml"

        create_object(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: configuration_file_object_path,
          content: File.read('spec/fixtures/custom-prometheus-config.yml')
        )
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'PROMETHEUS_CONFIGURATION_FILE_OBJECT_PATH' =>
              configuration_file_object_path
          }
        )

        execute_docker_entrypoint(
          started_indicator: 'Server is ready to receive web requests.'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'uses the provided configuration file' do
        expected = File.read('spec/fixtures/custom-prometheus-config.yml')
                       .gsub(/\${SELF_AVAILABILITY_ZONE}/, 'us-east-1a')
        actual = file('/opt/prometheus/conf/prometheus.yml').content

        expect(actual).to(eq(expected))
      end
    end
  end

  describe 'with rules configuration' do
    describe 'with one rule file object path provided' do
      before(:all) do
        rule_file_1_object_path = "#{s3_bucket_path}/rule_file_1.yml"

        create_object(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: rule_file_1_object_path,
          content: File.read('spec/fixtures/rule-file-1.yml')
        )
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'PROMETHEUS_RULE_FILE_OBJECT_PATHS' =>
              rule_file_1_object_path.to_s
          }
        )

        execute_docker_entrypoint(
          started_indicator: 'Server is ready to receive web requests.'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'fetches the specified rule file' do
        rule_files = command('ls /opt/prometheus/conf/rules').stdout

        expect(rule_files).to(eq("rule_file_1.yml\n"))
      end

      it 'fetches the correct rule file contents' do
        rule_file_content =
          command('cat /opt/prometheus/conf/rules/rule_file_1.yml').stdout

        expect(rule_file_content)
          .to(eq(File.read('spec/fixtures/rule-file-1.yml')))
      end
    end

    describe 'with many rule file object paths provided' do
      def create_bucket_object(content, path)
        create_object(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: path,
          content:
        )
      end

      def rule_file_1_object_path
        "#{s3_bucket_path}/rule_file_1.yml"
      end

      def rule_file_2_object_path
        "#{s3_bucket_path}/rule_file_2.yml"
      end

      before(:all) do
        create_bucket_object(
          File.read('spec/fixtures/rule-file-1.yml'),
          rule_file_1_object_path
        )

        create_bucket_object(
          File.read('spec/fixtures/rule-file-2.yml'),
          rule_file_2_object_path
        )

        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'PROMETHEUS_RULE_FILE_OBJECT_PATHS' =>
              "#{rule_file_1_object_path},#{rule_file_2_object_path}"
          }
        )

        execute_docker_entrypoint(
          started_indicator: 'Server is ready to receive web requests.'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'fetches the specified rule files' do
        rule_files = command('ls /opt/prometheus/conf/rules').stdout

        expect(rule_files).to(eq(
                                "rule_file_1.yml\n" \
                                "rule_file_2.yml\n"
                              ))
      end

      it 'fetches the correct rule file contents for the first rule file' do
        rule_file_1_content =
          command('cat /opt/prometheus/conf/rules/rule_file_1.yml').stdout

        expect(rule_file_1_content)
          .to(eq(File.read('spec/fixtures/rule-file-1.yml')))
      end

      it 'fetches the correct rule file contents for the second rule file' do
        rule_file_2_content =
          command('cat /opt/prometheus/conf/rules/rule_file_2.yml').stdout

        expect(rule_file_2_content)
          .to(eq(File.read('spec/fixtures/rule-file-2.yml')))
      end
    end
  end

  describe 'with storage configuration' do
    before(:all) do
      create_env_file(
        endpoint_url: s3_endpoint_url,
        region: s3_bucket_region,
        bucket_path: s3_bucket_path,
        object_path: s3_env_file_object_path,
        env: {
          'PROMETHEUS_STORAGE_TSDB_PATH' => '/data',
          'PROMETHEUS_STORAGE_TSDB_RETENTION_TIME' => '10d',
          'PROMETHEUS_STORAGE_TSDB_MINIMUM_BLOCK_DURATION' => '2h',
          'PROMETHEUS_STORAGE_TSDB_MAXIMUM_BLOCK_DURATION' => '2h'
        }
      )

      execute_docker_entrypoint(
        started_indicator: 'Server is ready to receive web requests.'
      )
    end

    after(:all, &:reset_docker_backend)

    it 'uses the provided TSDB path' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .to(match(%r{--storage\.tsdb\.path=/data}))
    end

    it 'uses the provided TSDB retention time' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .to(match(/--storage\.tsdb\.retention\.time=10d/))
    end

    it 'uses the provided TSDB minimum block duration' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .to(match(/--storage\.tsdb\.min-block-duration=2h/))
    end

    it 'uses the provided TSDB maximum block duration' do
      expect(process('/opt/prometheus/bin/prometheus').args)
        .to(match(/--storage\.tsdb\.max-block-duration=2h/))
    end
  end

  describe 'with web configuration' do
    describe 'for general options' do
      before(:all) do
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'PROMETHEUS_WEB_EXTERNAL_URL' =>
              'https://prometheus.example.com'
          }
        )

        execute_docker_entrypoint(
          started_indicator: 'Server is ready to receive web requests.'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'uses the specified external URL' do
        expect(process('/opt/prometheus/bin/prometheus').args)
          .to(match(%r{--web.external-url=https://prometheus.example.com}))
      end
    end

    describe 'for enabled admin API' do
      before(:all) do
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'PROMETHEUS_WEB_ADMIN_API_ENABLED' => 'yes'
          }
        )

        execute_docker_entrypoint(
          started_indicator: 'Server is ready to receive web requests.'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'includes the enable admin API flag' do
        expect(process('/opt/prometheus/bin/prometheus').args)
          .to(match(/--web.enable-admin-api/))
      end
    end

    describe 'for disabled admin API' do
      before(:all) do
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'PROMETHEUS_WEB_ADMIN_API_ENABLED' => 'no'
          }
        )

        execute_docker_entrypoint(
          started_indicator: 'Server is ready to receive web requests.'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'does not include the enable admin API flag' do
        expect(process('/opt/prometheus/bin/prometheus').args)
          .not_to(match(/--web.enable-admin-api/))
      end
    end

    describe 'for enabled lifecycle' do
      before(:all) do
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'PROMETHEUS_WEB_LIFECYCLE_ENABLED' => 'yes'
          }
        )

        execute_docker_entrypoint(
          started_indicator: 'Server is ready to receive web requests.'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'includes the enable lifecycle flag' do
        expect(process('/opt/prometheus/bin/prometheus').args)
          .to(match(/--web.enable-lifecycle/))
      end
    end

    describe 'for disabled lifecycle' do
      before(:all) do
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'PROMETHEUS_WEB_LIFECYCLE_ENABLED' => 'no'
          }
        )

        execute_docker_entrypoint(
          started_indicator: 'Server is ready to receive web requests.'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'does not include the enable lifecycle flag' do
        expect(process('/opt/prometheus/bin/prometheus').args)
          .not_to(match(/--web.enable-lifecycle/))
      end
    end
  end

  def reset_docker_backend
    Specinfra::Backend::Docker.instance.send :cleanup_container
    Specinfra::Backend::Docker.clear
  end

  def create_env_file(opts)
    create_object(
      opts
        .merge(
          content: (opts[:env] || {})
                     .to_a
                     .collect { |item| " #{item[0]}=\"#{item[1]}\"" }
                     .join("\n")
        )
    )
  end

  def execute_command(command_string)
    command = command(command_string)
    exit_status = command.exit_status
    unless exit_status == 0
      raise "\"#{command_string}\" failed with exit code: #{exit_status}"
    end

    command
  end

  def make_bucket(opts)
    execute_command('aws ' \
                    "--endpoint-url #{opts[:endpoint_url]} " \
                    's3 ' \
                    'mb ' \
                    "#{opts[:bucket_path]} " \
                    "--region \"#{opts[:region]}\"")
  end

  def copy_object(opts)
    execute_command("echo -n #{Shellwords.escape(opts[:content])} | " \
                    'aws ' \
                    "--endpoint-url #{opts[:endpoint_url]} " \
                    's3 ' \
                    'cp ' \
                    '- ' \
                    "#{opts[:object_path]} " \
                    "--region \"#{opts[:region]}\" " \
                    '--sse AES256')
  end

  def create_object(opts)
    make_bucket(opts)
    copy_object(opts)
  end

  def wait_for_contents(file, content)
    Octopoller.poll(timeout: 30) do
      docker_entrypoint_log = command("cat #{file}").stdout
      docker_entrypoint_log =~ /#{content}/ ? docker_entrypoint_log : :re_poll
    end
  rescue Octopoller::TimeoutError => e
    puts command("cat #{file}").stdout
    raise e
  end

  def execute_docker_entrypoint(opts)
    args = (opts[:arguments] || []).join(' ')
    logfile_path = '/tmp/docker-entrypoint.log'
    start_command = "docker-entrypoint.sh #{args} > #{logfile_path} 2>&1 &"
    started_indicator = opts[:started_indicator]

    execute_command(start_command)
    wait_for_contents(logfile_path, started_indicator)
  end
end
