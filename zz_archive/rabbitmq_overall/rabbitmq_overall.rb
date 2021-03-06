# Archived as later versions of RabbitMQ require root access for the rabbitmqctl command. 
#
# Created by Doug Barth.
# http://github.com/dougbarth/
class RabbitmqOverall < Scout::Plugin
  OPTIONS = <<-EOS
  rabbitmqctl:
    name: rabbitmqctl command
    notes: The command used to run the rabbitctl program, minus arguments
    default: rabbitmqctl
  EOS

  def build_report
    begin
      report_data = {}

      connection_stats = `#{rabbitmqctl} -q list_connections`.lines.to_a
      report_data['connections'] = connection_stats.size

      report_data['queues'] = report_data['messages'] = report_data['queue_mem'] = 0
      report_data['exchanges'] = 0
      report_data['bindings'] = 0
      vhosts.each do |vhost|
        queue_stats = `#{rabbitmqctl} -q list_queues -p '#{vhost}' messages memory`.lines.to_a
        report_data['queues'] += queue_stats.size
        report_data['messages'] += queue_stats.inject(0) do |sum, line|
          sum += line.split[0].to_i
        end

        report_data['queue_mem'] += queue_stats.inject(0) do |sum, line|
          sum += line.split[1].to_i
        end

        exchange_stats = `#{rabbitmqctl} -q list_exchanges -p #{vhost}`.lines.to_a
        report_data['exchanges'] += exchange_stats.size

        binding_stats = `#{rabbitmqctl} -q list_bindings -p #{vhost}`.lines.to_a
        report_data['bindings'] += binding_stats.size
      end

      # Convert queue memory from bytes to MB.
      report_data['queue_mem'] = report_data['queue_mem'].to_f / (1024 * 1024)

      report(report_data)
    rescue RuntimeError => e
      add_error(e.message)
    end
  end

  def rabbitmqctl
    option('rabbitmqctl')
  end

  def vhosts
    @vhosts ||= `#{rabbitmqctl} -q list_vhosts`.lines.to_a.map {|vhost| vhost.chomp }
  end

  def `(command)
    result = super(%{#{command} 2>&1})
    if ($? != 0)
      raise "#{command} exited with a non-zero value: #{$?} `#{result}'"
    end
    result
  end
end
