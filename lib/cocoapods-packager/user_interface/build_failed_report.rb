module Pod
  module UserInterface
    module BuildFailedReport
      class << self
        def report(command, output)
          <<-EOF
Build command failed: #{command}
Output:
#{output.map { |line| "    #{line}" }.join}
          EOF
        end
      end
    end
  end
end
