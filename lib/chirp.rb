require 'fileutils'

class Chirp
  Child = Struct.new(:script, :exitstatus)

  def initialize
    $stdout.sync = true
    $stderr.sync = true
  end

  def run!
    started = {}
    completed = []

    FileUtils.mkdir_p(logs_dir)

    start_dots if ENV.key?('CI')

    scripts.each do |script|
      if File.executable?(script)
        logfile = File.join(logs_dir, "#{File.basename(script)}.log")
        $stdout.puts "---> Spawning #{script.inspect}"
        pid = Process.spawn(script, [:out, :err] => [logfile, 'w'])
        started[pid] = Child.new(script, 0)
      end
    end

    loop do
      break if started.empty?

      started.clone.map do |pid, child|
        if Process.waitpid(pid, Process::WNOHANG)
          child = started.delete(pid)
          child.exitstatus = $?.exitstatus
          $stdout.puts "---> Done with #{child.script.inspect}, exit #{child.exitstatus}"
          completed << child
        end
      end

      sleep 0.2
    end

    completed.map(&:exitstatus).reduce(:+)
  end

  def scripts
    @scripts ||= Dir.glob(File.expand_path("#{scripts_dir}/*")).select do |script|
      script_filter =~ script
    end
  end

  def scripts_dir
    @scripts_dir ||= ENV.fetch('CHIRP_SCRIPTS', File.expand_path('../../scripts', __FILE__))
  end

  def logs_dir
    @logs_dir ||= ENV.fetch('CHIRP_LOGS', File.expand_path('../../log', __FILE__))
  end

  def script_filter
    @script_filter ||= %r{#{ENV['CHIRP_SCRIPT_FILTER'] || '.*'}}
  end

  def start_dots
    Thread.start do
      loop do
        $stderr.write '.'
        sleep 0.5
      end
    end
  end
end