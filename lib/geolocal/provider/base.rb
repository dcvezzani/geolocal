require 'ipaddr'


module Geolocal
  module Provider
    class Base
      def initialize params={}
        @config = params.merge(Geolocal.configuration.to_hash)
      end

      def config
        @config
      end

      def download
        download_files
      end

      def add_to_results results, name, lostr, histr
        loaddr = IPAddr.new(lostr)
        hiaddr = IPAddr.new(histr)
        lofam = loaddr.family
        hifam = hiaddr.family
        if lofam != hifam
          raise "#{lostr} and #{histr} must be in the same address family"
        end

        loval = loaddr.to_i
        hival = hiaddr.to_i
        if loval > hival
          raise "range supplied in the wrong order: #{lostr}..#{histr}"
        end

        if lofam == Socket::AF_INET
          namefam = name + 'v4' if config[:ipv4]
        elsif lofam == Socket::AF_INET6
          namefam = name + 'v6' if config[:ipv6]
        else
          raise "unknown address family #{lofam} for #{lostr}"
        end

        if namefam
          results[namefam] << (loaddr.to_i..hiaddr.to_i)
        end
        namefam
      end

      def update
        countries = config[:countries].reduce({}) { |a, (k, v)|
          a.merge! k.to_s.upcase => Array(v).map(&:upcase).to_set
        }

        results = countries.keys.reduce({}) { |a, k|
          a.merge! k.upcase+'v4' => [] if config[:ipv4]
          a.merge! k.upcase+'v6' => [] if config[:ipv6]
          a
        }

        read_ranges(countries) { |*args| add_to_results(results, *args) }

        File.open(config[:file], 'w') do |file|
          output(file, results)
        end

        status "done, result in #{config[:file]}\n"
      end

      def up_to_date?(file, expiry)
        return false unless File.exist?(file)
        diff = Time.now - File.mtime(file)
        if diff < expiry
          status "using #{file} since it's #{diff.round} seconds old\n"
          return true
        end
      end

      def output file, results
        modname = config[:module]

        write_header file, modname

        config[:countries].keys.each do |name|
          v4mod = config[:ipv4] ? name.to_s.upcase + 'v4' : 'nil'
          v6mod = config[:ipv6] ? name.to_s.upcase + 'v6' : 'nil'
          write_method file, name, v4mod, v6mod
        end
        file.write "end\n\n"

        status "  writing "
        results.each do |name, ranges|
          coalesced = coalesce_ranges(ranges)
          status "#{name}-#{ranges.length - coalesced.length} "
          write_ranges file, modname, name, coalesced
        end
        status "\n"
      end


      def coalesce_ranges ranges
        ranges = ranges.sort_by { |r| r.min }

        uniques = []
        lastr = ranges.shift
        uniques << lastr if lastr

        ranges.each do |thisr|
          if lastr.last >= thisr.first - 1
            lastr = lastr.first..[thisr.last, lastr.last].max
            uniques[-1] = lastr
          else
            lastr = thisr
            uniques << lastr
          end
        end

        uniques
      end


      def write_header file, modname
        file.write <<EOL
# This file is autogenerated by the Geolocal gem

module #{modname}

  def self.search address, family=nil, v4module, v6module
    address = IPAddr.new(address) if address.is_a?(String)
    family = address.family unless family
    num = address.to_i
    case family
      when Socket::AF_INET  then mod = v4module
      when Socket::AF_INET6 then mod = v6module
      else raise "Unknown family \#{family} for address \#{address}"
    end
    raise "ipv\#{family == 2 ? 4 : 6} was not compiled in" unless mod
    true if mod.bsearch { |range| num > range.max ? 1 : num < range.min ? -1 : 0 }
  end

EOL
      end

      def write_method file, name, v4mod, v6mod
        file.write <<EOL
  def self.in_#{name}? address, family=nil
    search address, family, #{v4mod}, #{v6mod}
  end

EOL
      end

      def write_ranges file, modname, name, ranges
        file.write <<EOL
#{modname}::#{name} = [
#{ranges.join(",\n")}
]

EOL
      end
    end
  end
end


# random utilities
module Geolocal
  module Provider
    class Base
      # returns elapsed time of block in seconds
      def time_block
        start = Time.now
        yield
        stop = Time.now
        stop - start + 0.0000001 # fudge to prevent division by zero
      end

      def status *args
        unless config[:quiet]
          Kernel.print(*args)
          $stdout.flush unless args.last.end_with?("\n")
        end
      end
    end
  end
end

