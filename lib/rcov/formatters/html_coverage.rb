module Rcov

  class HTMLCoverage < BaseFormatter # :nodoc:
    require 'fileutils'

      DEFAULT_OPTS = {:color => false, :fsr => 30, :destdir => "coverage",
                      :callsites => false, :cross_references => false,
                      :validator_links => true, :charset => nil
                     }
                     
      def initialize(opts = {})
        options = DEFAULT_OPTS.clone.update(opts)
        super(options)
        @dest = options[:destdir]
        @color = options[:color]
        @fsr = options[:fsr]
        @do_callsites = options[:callsites]
        @do_cross_references = options[:cross_references]
        @span_class_index = 0
        @show_validator_links = options[:validator_links]
        @charset = options[:charset]
      end

      def execute
        return if @files.empty?
        FileUtils.mkdir_p @dest
        create_index(File.join(@dest, "index.html"))
      
        each_file_pair_sorted do |filename, fileinfo|
          create_file(File.join(@dest, mangle_filename(filename)), fileinfo)
        end
      end

      private

      def blurb
          xmlish_ {
                  p_ {
                      t_{ "Generated using the " }
                      a_(:href => "http://eigenclass.org/hiki.rb?rcov") {
                          t_{ "rcov code coverage analysis tool for Ruby" }
                      }
                      t_{ " version #{Rcov::VERSION}." }
                  }
          }.pretty
      end

      def output_color_table?
        true
      end

      def default_color
        "rgb(240, 240, 245)"
      end

      def default_title
        "C0 code coverage information"
      end


      class SummaryFileInfo  # :nodoc:
        
        def initialize(obj)
          @o = obj 
        end
      
        def num_lines
          @o.num_lines
        end
      
        def num_code_lines
          @o.num_code_lines
        end
      
        def code_coverage
          @o.code_coverage
        end

        def code_coverage_for_report
          code_coverage * 100
        end

        def total_coverage
          @o.total_coverage
        end

        def total_coverage_for_report
          total_coverage * 100
        end
      
        def name
          "TOTAL" 
        end

      end

      def create_index(destname)
          files = [SummaryFileInfo.new(self)] + each_file_pair_sorted.map{|k,v| v}

          doc = Document.new('index.html.erb', :title => default_title, 
                                               :generated_on => Time.now,
                                               :rcov => Rcov,
                                               :output_threshold => @output_threshold,
                                               :files => files)

          File.open(destname, "w")  { |f| f.puts doc.render }
      end

      def format_lines(file)
          result = ""
          last = nil
          end_of_span = ""
          format_line = "%#{file.num_lines.to_s.size}d"
          file.num_lines.times do |i|
              line = file.lines[i].chomp
              marked = file.coverage[i]
              count = file.counts[i]
              spanclass = span_class(file, marked, count)
              if spanclass != last
                  result += end_of_span
                  case spanclass
                  when nil
                      end_of_span = ""
                  else
                      result += %[<span class="#{spanclass}">]
                      end_of_span = "</span>"
                  end
              end
              result += %[<a name="line#{i+1}"></a>] + (format_line % (i+1)) +
                  " " + create_cross_refs(file.name, i+1, CGI.escapeHTML(line)) + "\n"
              last = spanclass
          end
          result += end_of_span
          "<pre>#{result}</pre>"
      end

      def create_cross_refs(filename, lineno, linetext)
          return linetext unless @callsite_analyzer && @do_callsites
          ref_blocks = []
          _get_defsites(ref_blocks, filename, lineno, "Calls", linetext) do |ref|
              if ref.file
                  where = "at #{normalize_filename(ref.file)}:#{ref.line}"
              else
                  where = "(C extension/core)"
              end
              CGI.escapeHTML("%7d   %s" %
                                 [ref.count, "#{ref.klass}##{ref.mid} " + where])
          end
          _get_callsites(ref_blocks, filename, lineno, "Called by", linetext) do |ref|
              r = "%7d   %s" % [ref.count,
                  "#{normalize_filename(ref.file||'C code')}:#{ref.line} " +
                      "in '#{ref.klass}##{ref.mid}'"]
              CGI.escapeHTML(r)
          end

          create_cross_reference_block(linetext, ref_blocks)
      end

      def create_cross_reference_block(linetext, ref_blocks)
          return linetext if ref_blocks.empty?
          ret = ""
          @cross_ref_idx ||= 0
          @known_files ||= sorted_file_pairs.map{|fname, finfo| normalize_filename(fname)}
          ret << %[<a class="crossref-toggle" href="#" onclick="toggleCode('XREF-#{@cross_ref_idx+=1}'); return false;">#{linetext}</a>]
          ret << %[<span class="cross-ref" id="XREF-#{@cross_ref_idx}">]
          ret << "\n"
          ref_blocks.each do |refs, toplabel, label_proc|
              unless !toplabel || toplabel.empty?
                  ret << %!<span class="cross-ref-title">#{toplabel}</span>\n!
              end
              refs.each do |dst|
                  dstfile = normalize_filename(dst.file) if dst.file
                  dstline = dst.line
                  label = label_proc.call(dst)
                  if dst.file && @known_files.include?(dstfile)
                      ret << %[<a href="#{mangle_filename(dstfile)}#line#{dstline}">#{label}</a>]
                  else
                      ret << label
                  end
                  ret << "\n"
              end
          end
          ret << "</span>"
      end

      def span_class(sourceinfo, marked, count)
          @span_class_index ^= 1
          case marked
          when true
              "marked#{@span_class_index}"
          when :inferred
              "inferred#{@span_class_index}"
          else
              "uncovered#{@span_class_index}"
          end
      end

      def create_file(destfile, fileinfo)
          doc = Document.new('detail.html.erb', :title => default_title, 
                                                :generated_on => Time.now,
                                                :rcov => Rcov,
                                                :output_threshold => @output_threshold,
                                                :file => fileinfo,
                                                :body => format_lines(fileinfo))
          File.open(destfile, "w")  { |f| f.puts doc.render }
      end

      def colorscale
colorscalebase =<<EOF
span.run%d {
  background-color: rgb(%d, %d, %d);
  display: block;
}
EOF
          cscale = ""
          101.times do |i|
              if @color
                  r, g, b = hsv2rgb(220-(2.2*i).to_i, 0.3, 1)
                  r = (r * 255).to_i
                  g = (g * 255).to_i
                  b = (b * 255).to_i
              else
                  r = g = b = 255 - i
              end
              cscale << colorscalebase % [i, r, g, b]
          end
          cscale
      end

      # thanks to kig @ #ruby-lang for this one
      def hsv2rgb(h,s,v)
          return [v,v,v] if s == 0
          h = h/60.0
          i = h.floor
          f = h-i
          p = v * (1-s)
          q = v * (1-s*f)
          t = v * (1-s*(1-f))
          case i
          when 0
              r = v
              g = t
              b = p
          when 1
              r = q
              g = v
              b = p
          when 2
              r = p
              g = v
              b = t
          when 3
              r = p
              g = q
              b = v
          when 4
              r = t
              g = p
              b = v
          when 5
              r = v
              g = p
              b = q
          end
          [r,g,b]
      end
  end

  class HTMLProfiling < HTMLCoverage # :nodoc:

      DEFAULT_OPTS = {:destdir => "profiling"}
      def initialize(opts = {})
          options = DEFAULT_OPTS.clone.update(opts)
          super(options)
          @max_cache = {}
          @median_cache = {}
      end

      def default_title
          "Bogo-profile information"
      end

      def default_color
          if @color
              "rgb(179,205,255)"
          else
              "rgb(255, 255, 255)"
          end
      end

      def output_color_table?
          false
      end

      def span_class(sourceinfo, marked, count)
          full_scale_range = @fsr # dB
          nz_count = sourceinfo.counts.select{|x| x && x != 0}
          nz_count << 1 # avoid div by 0
          max = @max_cache[sourceinfo] ||= nz_count.max
          #avg = @median_cache[sourceinfo] ||= 1.0 *
          #    nz_count.inject{|a,b| a+b} / nz_count.size
          median = @median_cache[sourceinfo] ||= 1.0 * nz_count.sort[nz_count.size/2]
          max ||= 2
          max = 2 if max == 1
          if marked == true
              count = 1 if !count || count == 0
              idx = 50 + 1.0 * (500/full_scale_range) * Math.log(count/median) / Math.log(10)
              idx = idx.to_i
              idx = 0 if idx < 0
              idx = 100 if idx > 100
              "run#{idx}"
          else
              nil
          end
      end
    
  end

  class RubyAnnotation < BaseFormatter # :nodoc:
      DEFAULT_OPTS = { :destdir => "coverage" }
      def initialize(opts = {})
          options = DEFAULT_OPTS.clone.update(opts)
          super(options)
          @dest = options[:destdir]
          @do_callsites = true
          @do_cross_references = true

          @mangle_filename = Hash.new{|h,base|
              h[base] = Pathname.new(base).cleanpath.to_s.gsub(%r{^\w:[/\\]}, "").gsub(/\./, "_").gsub(/[\\\/]/, "-") + ".rb"
          }
      end

      def execute
          return if @files.empty?
          FileUtils.mkdir_p @dest
          each_file_pair_sorted do |filename, fileinfo|
              create_file(File.join(@dest, mangle_filename(filename)), fileinfo)
          end
      end

      private

      def format_lines(file)
          result = ""
          format_line = "%#{file.num_lines.to_s.size}d"
          file.num_lines.times do |i|
              line = file.lines[i].chomp
              marked = file.coverage[i]
              count = file.counts[i]
              result << create_cross_refs(file.name, i+1, line, marked) + "\n"
          end
          result
      end

      def create_cross_refs(filename, lineno, linetext, marked)
          return linetext unless @callsite_analyzer && @do_callsites
          ref_blocks = []
          _get_defsites(ref_blocks, filename, lineno, linetext, ">>") do |ref|
              if ref.file
                  ref.file.sub!(%r!^./!, '')
                  where = "at #{mangle_filename(ref.file)}:#{ref.line}"
              else
                  where = "(C extension/core)"
              end
              "#{ref.klass}##{ref.mid} " + where + ""
          end
          _get_callsites(ref_blocks, filename, lineno, linetext, "<<") do |ref| # "
              ref.file.sub!(%r!^./!, '')
              "#{mangle_filename(ref.file||'C code')}:#{ref.line} " +
                  "in #{ref.klass}##{ref.mid}"
          end

          create_cross_reference_block(linetext, ref_blocks, marked)
      end

      def create_cross_reference_block(linetext, ref_blocks, marked)
          codelen = 75
          if ref_blocks.empty?
              if marked
                  return "%-#{codelen}s #o" % linetext
              else
                  return linetext
              end
          end
          ret = ""
          @cross_ref_idx ||= 0
          @known_files ||= sorted_file_pairs.map{|fname, finfo| normalize_filename(fname)}
          ret << "%-#{codelen}s # " % linetext
          ref_blocks.each do |refs, toplabel, label_proc|
              unless !toplabel || toplabel.empty?
                  ret << toplabel << " "
              end
              refs.each do |dst|
                  dstfile = normalize_filename(dst.file) if dst.file
                  dstline = dst.line
                  label = label_proc.call(dst)
                  if dst.file && @known_files.include?(dstfile)
                      ret << "[[" << label << "]], "
                  else
                      ret << label << ", "
                  end
              end
          end

          ret
      end

      def create_file(destfile, fileinfo)
        #body = format_lines(fileinfo)
        #File.open(destfile, "w") do |f|
          #f.puts body
          #f.puts footer(fileinfo)
        #end
      end

      def footer(fileinfo)
        s  = "# Total lines    : %d\n" % fileinfo.num_lines
        s << "# Lines of code  : %d\n" % fileinfo.num_code_lines
        s << "# Total coverage : %3.1f%%\n" % [ fileinfo.total_coverage*100 ]
        s << "# Code coverage  : %3.1f%%\n\n" % [ fileinfo.code_coverage*100 ]
        # prevents false positives on Emacs
        s << "# Local " "Variables:\n" "# mode: " "rcov-xref\n" "# End:\n"
      end
    end

end