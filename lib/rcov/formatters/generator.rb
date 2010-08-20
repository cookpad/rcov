module Rcov
  module Formatters
    class Generator
      def self.formatters(options)
        formatters = []
        make = make_formatter
        if options.html
          if options.profiling
            formatters << make_formatter[Rcov::HTMLProfiling]
          else
            formatters << make_formatter[Rcov::HTMLCoverage]
          end
        end


        if textual_formatters[options.textmode]
          formatters << make_formatter[textual_formatters[options.textmode]]
        end


        if options.failure_threshold.nil? == false && options.textmode != :failure_report
          formatters << make_formatter[textual_formatters[:failure_report]]
        end

        formatters << make_formatter[Rcov::TextCoverageDiff] if options.coverage_diff_save

      end

      def self.text_formatters
        textual_formatters = { :counts => Rcov::FullTextReport, :coverage => Rcov::FullTextReport,
          :gcc => Rcov::FullTextReport, :annotate => Rcov::RubyAnnotation,
          :summary => Rcov::TextSummary, :report => Rcov::TextReport,
          :coverage_diff => Rcov::TextCoverageDiff, :failure_report => Rcov::FailureReport }

      end

      def self.make_formatter
        lambda do |klass| 
          klass.new(:destdir => options.destdir, :color => options.color, 
                    :fsr => options.range, :textmode => options.textmode,
                    :ignore => options.skip, :dont_ignore => options.include, 
                    :sort => options.sort,
                    :sort_reverse => options.sort_reverse, 
                    :output_threshold => options.output_threshold,
                    :callsite_analyzer => $rcov_callsite_analyzer,
                    :coverage_diff_mode => options.coverage_diff_mode,
                    :coverage_diff_file => options.coverage_diff_file,
                    :callsites => options.callsites, 
                    :cross_references => options.crossrefs,
                    :diff_cmd => options.diff_cmd,
                    :comments_run_by_default => options.comments_run_by_default,
                    :gcc_output => options.gcc_output,
                    :charset => options.charset,
                    :css => options.css,
                    :failure_threshold => options.failure_threshold
                   )
        end
      end
    end
  end
end
