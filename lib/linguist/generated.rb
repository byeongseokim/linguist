module Linguist
  class Generated
    # Public: Is the blob a generated file?
    #
    # name - String filename
    # data - String blob data. A block also maybe passed in for lazy
    #        loading. This behavior is deprecated and you should always
    #        pass in a String.
    #
    # Return true or false
    def self.generated?(name, data)
      new(name, data).generated?
    end

    # Internal: Initialize Generated instance
    #
    # name - String filename
    # data - String blob data
    def initialize(name, data)
      @name = name
      @extname = File.extname(name)
      @_data = data
    end

    attr_reader :name, :extname

    # Lazy load blob data if block was passed in.
    #
    # Awful, awful stuff happening here.
    #
    # Returns String data.
    def data
      @data ||= @_data.respond_to?(:call) ? @_data.call() : @_data
    end

    # Public: Get each line of data
    #
    # Returns an Array of lines
    def lines
      # TODO: data should be required to be a String, no nils
      @lines ||= data ? data.split("\n", -1) : []
    end

    # Internal: Is the blob a generated file?
    #
    # Generated source code is suppressed in diffs and is ignored by
    # language statistics.
    #
    # Please add additional test coverage to
    # `test/test_blob.rb#test_generated` if you make any changes.
    #
    # Return true or false
    def generated?
      name == 'Gemfile.lock' ||
        minified_javascript? ||
        compiled_coffeescript? ||
        xcode_project_file? ||
        generated_net_docfile? ||
        generated_parser? ||
        generated_protocol_buffer?
    end

    # Internal: Is the blob an XCode project file?
    #
    # Generated if the file extension is an XCode project
    # file extension.
    #
    # Returns true of false.
    def xcode_project_file?
      ['.xib', '.nib', '.storyboard', '.pbxproj', '.xcworkspacedata', '.xcuserstate'].include?(extname)
    end

    # Internal: Is the blob minified JS?
    #
    # Consider JS minified if the average line length is
    # greater then 100c.
    #
    # Returns true or false.
    def minified_javascript?
      return unless extname == '.js'
      if lines.any?
        (lines.inject(0) { |n, l| n += l.length } / lines.length) > 100
      else
        false
      end
    end

    # Internal: Is the blob of JS generated by CoffeeScript?
    #
    # CoffeeScript is meant to output JS that would be difficult to
    # tell if it was generated or not. Look for a number of patterns
    # output by the CS compiler.
    #
    # Return true or false
    def compiled_coffeescript?
      return false unless extname == '.js'

      # CoffeeScript generated by > 1.2 include a comment on the first line
      if lines[0] =~ /^\/\/ Generated by /
        return true
      end

      if lines[0] == '(function() {' &&     # First line is module closure opening
          lines[-2] == '}).call(this);' &&  # Second to last line closes module closure
          lines[-1] == ''                   # Last line is blank

        score = 0

        lines.each do |line|
          if line =~ /var /
            # Underscored temp vars are likely to be Coffee
            score += 1 * line.gsub(/(_fn|_i|_len|_ref|_results)/).count

            # bind and extend functions are very Coffee specific
            score += 3 * line.gsub(/(__bind|__extends|__hasProp|__indexOf|__slice)/).count
          end
        end

        # Require a score of 3. This is fairly arbitrary. Consider
        # tweaking later.
        score >= 3
      else
        false
      end
    end

    # Internal: Is this a generated documentation file for a .NET assembly?
    #
    # .NET developers often check in the XML Intellisense file along with an
    # assembly - however, these don't have a special extension, so we have to
    # dig into the contents to determine if it's a docfile. Luckily, these files
    # are extremely structured, so recognizing them is easy.
    #
    # Returns true or false
    def generated_net_docfile?
      return false unless extname.downcase == ".xml"
      return false unless lines.count > 3

      # .NET Docfiles always open with <doc> and their first tag is an
      # <assembly> tag
      return lines[1].include?("<doc>") &&
        lines[2].include?("<assembly>") &&
        lines[-2].include?("</doc>")
    end

    # Internal: Is the blob of JS a parser generated by PEG.js?
    #
    # PEG.js-generated parsers are not meant to be consumed by humans.
    #
    # Return true or false
    def generated_parser?
      return false unless extname == '.js'

      # PEG.js-generated parsers include a comment near the top  of the file
      # that marks them as such.
      if lines[0..4].join('') =~ /^(?:[^\/]|\/[^\*])*\/\*(?:[^\*]|\*[^\/])*Generated by PEG.js/
        return true
      end

      false
    end

    # Internal: Is the blob a C++, Java or Python source file generated by the
    # Protocol Buffer compiler?
    #
    # Returns true of false.
    def generated_protocol_buffer?
      return false unless ['.py', '.java', '.h', '.cc', '.cpp'].include?(extname)
      return false unless lines.count > 1

      return lines[0].include?("Generated by the protocol buffer compiler.  DO NOT EDIT!")
    end
  end
end
