# Modified version of https://raw.github.com/jruby/jruby/master/bench/shootout/hash.ruby

require_relative '../lib/dot_profile_printer'

profile = JRuby::Profiler.profile do
  n = (ARGV.shift || 1).to_i

  hash = {}
  for i in 1..n
      hash['%x' % i] = 1
  end

  c = 0
  n.downto 1 do |i|
      c += 1 if hash.has_key? i.to_s
  end
end

File.open(File.expand_path('../hash.gv', __FILE__), 'w') do |io|
  JRuby::Profiler::DotProfilePrinter.new(profile).print_profile(io)
end