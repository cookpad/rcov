require 'ostruct'
module Rcov
  class Options
    def self.parse!(argv)
      options = default_options
      opts(options).parse!(argv)

      options.callsites = true if options.report_cov_bug_for
      options.textmode = :gcc if !options.textmode and options.gcc_output
    end

    def self.default_options
      options = OpenStruct.new
      options.color = true
      options.range = 30.0
      options.profiling = false
      options.destdir = nil
      options.loadpaths = []
      options.textmode = false
      options.skip = Rcov::BaseFormatter::DEFAULT_OPTS[:ignore]
      options.include = []
      options.html = true
      options.css = nil
      options.comments_run_by_default = false
      options.test_unit_only = false
      options.spec_only = false
      options.sort = :name
      options.sort_reverse = false
      options.output_threshold = 101
      options.failure_threshold = nil
      options.replace_prog_name = false
      options.callsites = false
      options.crossrefs = false
      options.coverage_diff_file = "coverage.info"
      options.coverage_diff_mode = :compare
      options.coverage_diff_save = false
      options.diff_cmd = "diff"
      options.report_cov_bug_for = nil
      options.aggregate_file = nil
      options.gcc_output = false
      options.charset = nil
      options.destdir = "coverage"
      return options
    end

    def self.opts(options)
      opts = OptionParser.new do |opts|
        opts.banner = <<-EOF
rcov #{Rcov::VERSION} #{Rcov::RELEASE_DATE}
Usage: rcov [options] <script1.rb> [script2.rb] [-- --extra-options]
EOF
      opts.separator ""
      opts.separator "Options:"

      opts.on("-o", "--output PATH", "Destination directory.") do |dir|
        options.destdir = dir
      end

      opts.on("-I", "--include PATHS", "Prepend PATHS to $: (colon separated list)") do |paths|
        options.loadpaths = paths.split(/:/)
      end

      opts.on("--[no-]comments", "Mark all comments by default.", "(default: --no-comments)") do |comments_run_p|
        options.comments_run_by_default = comments_run_p
      end

      opts.on("--test-unit-only", "Only trace code executed inside TestCases.") do
        deprecated("--test-unit-only")
      end

      opts.on("--spec-only", "Only trace code executed inside RSpec specs.") do
        deprecated("--spec-only")
      end

      opts.on("-n", "--no-color", "Create colorblind-safe output.") do
        options.color = false
      end

      opts.on("-i", "--include-file PATTERNS", 
              "Generate info for files matching a",
              "pattern (comma-separated regexp list)") do |list|
        begin
          regexps = list.split(/,/).map{|x| Regexp.new(x) }
          options.include += regexps
        rescue RegexpError => e
          raise OptionParser::InvalidArgument, e.message
        end
      end

      opts.on("-x", "--exclude PATTERNS", "Don't generate info for files matching a","pattern (comma-separated regexp list)") do |list|
        begin
          regexps = list.split(/,/).map{|x| Regexp.new x}
          options.skip += regexps
        rescue RegexpError => e
          raise OptionParser::InvalidArgument, e.message
        end
      end

      opts.on("--exclude-only PATTERNS", "Skip info only for files matching the", "given patterns.") do |list|
        begin
          options.skip = list.split(/,/).map{|x| Regexp.new(x) }
        rescue RegexpError => e
          raise OptionParser::InvalidArgument, e.message
        end
      end

      opts.on("--rails", "Skip config/, environment/ and vendor/.") do 
        options.skip.concat [%r{\bvendor/},%r{\bconfig/},%r{\benvironment/}]
      end

      opts.on("--[no-]callsites", "Show callsites in generated XHTML report.", "(somewhat slower; disabled by default)") do |val|
        options.callsites = val
      end

      opts.on("--[no-]xrefs", "Generate fully cross-referenced report.", "(includes --callsites)") do |val|
        options.crossrefs = val
        options.callsites ||= val
      end

      opts.on("-p", "--profile", "Generate bogo-profiling info.") do
        options.profiling = true
        options.destdir ||= "profiling"
      end

      opts.on("-r", "--range RANGE", Float, "Color scale range for profiling info (dB).") do |val|
        options.range = val
      end

      opts.on("-a", "--annotate", "Generate annotated source code.") do
        options.html = false
        options.textmode = :annotate
        options.crossrefs = true
        options.callsites = true
        options.skip = [ %r!/test/unit/! ]
      end

      opts.on("-T", "--text-report", "Dump detailed plain-text report to stdout.", "(filename, LoC, total lines, coverage)") do
        options.textmode = :report
      end

      opts.on("-t", "--text-summary", "Dump plain-text summary to stdout.") do
        options.textmode = :summary
      end

      opts.on("--text-counts", "Dump execution counts in plaintext.") do
        options.textmode = :counts
      end

      opts.on("--text-coverage", "Dump coverage info to stdout, using", "ANSI color sequences unless -n.") do
        options.textmode = :coverage
      end

      opts.on("--gcc", "Dump uncovered line in GCC error format.") do
        options.gcc_output = true
      end

      opts.on("--aggregate FILE", "Aggregate data from previous runs",
              "in FILE. Overwrites FILE with the",
              "merged data. FILE is created if",
              "necessary.") do |file|
        options.aggregate_file = file
      end

      opts.on("-D [FILE]", "--text-coverage-diff [FILE]",
              "Compare code coverage with saved state",
              "in FILE, defaults to coverage.info.",
              "Implies --comments.") do |file|
        options.textmode = :coverage_diff
        options.comments_run_by_default = true
        if options.coverage_diff_save
          raise "You shouldn't use --save and --text-coverage-diff at a time."
        end
        options.coverage_diff_mode = :compare
        options.coverage_diff_file = file if file && !file.empty?
      end

      opts.on("--save [FILE]", "Save coverage data to FILE,", "for later use with rcov -D.", "(default: coverage.info)") do |file|
        options.coverage_diff_save = true
        options.coverage_diff_mode = :record
        if options.textmode == :coverage_diff
          raise "You shouldn't use --save and --text-coverage-diff at a time."
        end
        options.coverage_diff_file = file if file && !file.empty?
      end

      opts.on("--[no-]html", "Generate HTML output.", "(default: --html)") do |val|
        options.html = val
      end

      opts.on("--css relative/path/to/custom.css", "Use a custom CSS file for HTML output.", "Specified as a relative path.") do |val|
        options.css = val
      end

      opts.on("--sort CRITERION", [:name, :loc, :coverage], "Sort files in the output by the specified", "field (name, loc, coverage)") do |criterion|
        options.sort = criterion
      end

      opts.on("--sort-reverse", "Reverse files in the output.") do
        options.sort_reverse = true
      end

      opts.on("--threshold INT", "Only list files with coverage < INT %.", "(default: 101)") do |threshold|
        begin
          threshold = Integer(threshold)
          raise if threshold <= 0 || threshold > 101
        rescue Exception
          raise OptionParser::InvalidArgument, threshold
        end
        options.output_threshold = threshold
      end

      opts.on("--failure-threshold [INT]", "Fail if the coverage is below the threshold", "(default: 100)") do |threshold|
        options.failure_threshold = (threshold || 100).to_i
        options.textmode = :failure_report
      end

      opts.on("--charset CHARSET", "Charset used in Content-Type declaration of HTML reports.") do |c|
        options.charset = c
      end

      opts.on("--only-uncovered", "Same as --threshold 100") do
        options.output_threshold = 100
      end

      opts.on("--replace-progname", "Replace $0 when loading the .rb files.") do
        options.replace_prog_name = true
      end

      opts.on("-w", "Turn warnings on (like ruby).") do
        $VERBOSE = true
      end

      opts.on("--no-rcovrt", "Do not use the optimized C runtime.", "(will run 30-300 times slower)") do 
        $rcov_do_not_use_rcovrt = true
      end

      opts.on("--diff-cmd PROGNAME", "Use PROGNAME for --text-coverage-diff.",
              "(default: diff)") do |cmd|
        options.diff_cmd = cmd
              end

      opts.separator ""

      opts.on_tail("-h", "--help", "Show extended help message") do
        require 'pp'
        puts opts
        puts <<EOF

Files matching any of the following regexps will be omitted in the report(s):
        #{PP.pp(options.skip, "").chomp}
EOF
        puts EXTRA_HELP
        exit
      end

      opts.on_tail("--report-cov-bug SELECTOR", "Report coverage analysis bug for the",
                   "method specified by SELECTOR", "(format: Foo::Bar#method, A::B.method)") do |selector|
        case selector
        when /([^.]+)(#|\.)(.*)/ then options.report_cov_bug_for = selector
        else
          raise OptionParser::InvalidArgument, selector
        end
        options.textmode = nil
        options.html = false
        options.callsites = true
                   end
      opts.on_tail("--version", "Show version") do
        puts "rcov " + Rcov::VERSION + " " + Rcov::RELEASE_DATE
        exit
      end
      end
    end
  end
end
