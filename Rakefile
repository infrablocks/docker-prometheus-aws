require 'rake_docker'
require 'rake_circle_ci'
require 'rake_github'
require 'rake_ssh'
require 'rake_gpg'
require 'rake_terraform'
require 'securerandom'
require 'yaml'
require 'git'
require 'os'
require 'semantic'
require 'rspec/core/rake_task'

require_relative 'lib/version'

Docker.options = {
    read_timeout: 300
}

def repo
  Git.open('.')
end

def latest_tag
  repo.tags.map do |tag|
    Semantic::Version.new(tag.name)
  end.max
end

def tmpdir
  base = (ENV["TMPDIR"] || "/tmp")
  OS.osx? ? "/private" + base : base
end

task :default => :'test:integration'

namespace :encryption do
  namespace :passphrase do
    task :generate do
      File.open('config/secrets/ci/encryption.passphrase', 'w') do |f|
        f.write(SecureRandom.base64(36))
      end
    end
  end
end

namespace :keys do
  namespace :deploy do
    RakeSSH.define_key_tasks(
        path: 'config/secrets/ci/',
        comment: 'maintainers@infrablocks.io')
  end

  namespace :gpg do
    RakeGPG.define_generate_key_task(
        output_directory: 'config/secrets/ci',
        name_prefix: 'gpg',
        owner_name: 'InfraBlocks Maintainers',
        owner_email: 'maintainers@infrablocks.io',
        owner_comment: 'docker-prometheus-aws CI Key')
  end
end

RakeCircleCI.define_project_tasks(
    namespace: :circle_ci,
    project_slug: 'github/infrablocks/docker-prometheus-aws'
) do |t|
  circle_ci_config =
      YAML.load_file('config/secrets/circle_ci/config.yaml')

  t.api_token = circle_ci_config["circle_ci_api_token"]
  t.environment_variables = {
      ENCRYPTION_PASSPHRASE:
          File.read('config/secrets/ci/encryption.passphrase')
              .chomp
  }
  t.checkout_keys = []
  t.ssh_keys = [
      {
          hostname: "github.com",
          private_key: File.read('config/secrets/ci/ssh.private')
      }
  ]
end

RakeGithub.define_repository_tasks(
    namespace: :github,
    repository: 'infrablocks/docker-prometheus-aws'
) do |t|
  github_config =
      YAML.load_file('config/secrets/github/config.yaml')

  t.access_token = github_config["github_personal_access_token"]
  t.deploy_keys = [
      {
          title: 'CircleCI',
          public_key: File.read('config/secrets/ci/ssh.public')
      }
  ]
end

namespace :pipeline do
  task :prepare => [
      :'circle_ci:project:follow',
      :'circle_ci:env_vars:ensure',
      :'circle_ci:checkout_keys:ensure',
      :'circle_ci:ssh_keys:ensure',
      :'github:deploy_keys:ensure'
  ]
end

namespace :image do
  RakeDocker.define_image_tasks(
      image_name: 'prometheus-aws'
  ) do |t|
    t.work_directory = 'build/images'

    t.copy_spec = [
        "src/prometheus-aws/Dockerfile",
        "src/prometheus-aws/start.sh",
        "src/prometheus-aws/scripts",
    ]

    t.repository_name = 'prometheus-aws'
    t.repository_url = 'infrablocks/prometheus-aws'

    t.credentials = YAML.load_file(
        "config/secrets/dockerhub/credentials.yaml")

    t.tags = [latest_tag.to_s, 'latest']
  end
end

namespace :dependencies do
  namespace :test do
    desc "Provision spec dependencies"
    task :provision do
      project_name = "docker_prometheus_aws_test"
      compose_file = "spec/dependencies.yml"

      project_name_switch = "--project-name #{project_name}"
      compose_file_switch = "--file #{compose_file}"
      detach_switch = "--detach"
      remove_orphans_switch = "--remove-orphans"

      command_switches = "#{compose_file_switch} #{project_name_switch}"
      subcommand_switches = "#{detach_switch} #{remove_orphans_switch}"

      sh({
          "TMPDIR" => tmpdir,
      }, "docker-compose #{command_switches} up #{subcommand_switches}")
    end

    desc "Destroy spec dependencies"
    task :destroy do
      project_name = "docker_prometheus_aws_test"
      compose_file = "spec/dependencies.yml"

      project_name_switch = "--project-name #{project_name}"
      compose_file_switch = "--file #{compose_file}"

      command_switches = "#{compose_file_switch} #{project_name_switch}"

      sh({
          "TMPDIR" => tmpdir,
      }, "docker-compose #{command_switches} down")
    end
  end
end

namespace :test do
  RSpec::Core::RakeTask.new(:integration => [
      'image:build',
      'dependencies:test:provision'
  ]) do |t|
    t.rspec_opts = ["--format", "documentation"]
  end
end

namespace :version do
  task :bump, [:type] do |_, args|
    next_tag = latest_tag.send("#{args.type}!")
    repo.add_tag(next_tag.to_s)
    repo.push('origin', 'master', tags: true)
  end

  task :release do
    next_tag = latest_tag.release!
    repo.add_tag(next_tag.to_s)
    repo.push('origin', 'master', tags: true)
  end
end
