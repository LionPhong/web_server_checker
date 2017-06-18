require 'httparty'
require 'nokogiri'
require 'ipaddress'
require 'resolv'

USAGE = <<ENDUSAGE
Usage:
   web_server_checker.rb [options] [protocol] [ports] ip_list
ENDUSAGE

HELP = <<ENDHELP
   -h, --help       Show this help.
   -v, --version    Show the version number.
   -l, --logfile    Specify the filename to log to.
   -p, --ports      Ports to check (comma seperated, no spaces). 
   -V. --verbose    Output in verbose mode. (NOT YET IMPLEMENTED)
   -http            Run using HTTP.
   -https           Run using HTTPS.
ENDHELP

VERSION = <<ENDVERSION
Version: web_server_checker 1.0
ENDVERSION

ARGS = { :help=>false, :version=>false, :ports=>false, :verbose=>false, :http=>false, :https=>false}
UNFLAGGED_ARGS = [ :directory ]              # Bare arguments (no flag)
next_arg = UNFLAGGED_ARGS.first
files = Array.new
live_list = Array.new
ARGV.each do |arg|
  case arg
    when '-h','--help'      then ARGS[:help]      = true
    when '-v','--version'   then ARGS[:version]   = true
    when '-V','--verbose'   then ARGS[:verbose]   = true
    when '-http'            then ARGS[:http]      = true
    when '-https'           then ARGS[:https]     = true
    when '-l','--logfile'   then next_arg = :logfile
    when '-p','--ports'     then next_arg = :ports
    else
    	if File.exist?(arg)
			files.push(arg)
		end
	    if next_arg
	    	ARGS[next_arg] = arg
	      	UNFLAGGED_ARGS.delete( next_arg )
	    end
	    next_arg = UNFLAGGED_ARGS.first
  end
end

if ARGS[:help] or !ARGS[:directory] and !ARGS[:version]
	puts HELP if ARGS[:help]
	exit
end

if ARGS[:version]
	puts VERSION
end

if ARGS[:logfile]
	$stdout.reopen( ARGS[:logfile], "w" )
	$stdout.sync = true
	$stderr.reopen( $stdout )
end

if ARGS[:ports]
	port_list = ARGS[:ports]
	port_list = port_list.split(",")
else
	port_list = [80]
end

def ip_table_builder(ip_lists)
	valid_ips = []
	ip_lists.each_with_index do|list, i|
		doc = File.open(list)
		doc.each do |ip|
			ip = ip.chomp
			if IPAddress.valid?(ip)
				valid_ips.push(ip)
			else
				if Resolv.getaddresses(ip)#fails here
					if IPAddress.valid?(ip)
						valid_ips.push(ip)
					end
				end
			end
		end	
	end
	return valid_ips
end

def server_checker_http(ip_lists, port_list)
	http_live_list = Array.new
	list = ip_table_builder(ip_lists)
	list.each do |ip|
		port_list.each do |port|
			begin
				response = HTTParty.get("http://#{ip}:#{port}", { timeout: 10 })
			rescue 
				if ARGS[:verbose]
  					$stderr.print "\nhttp://#{ip}:#{port} request failed"
  				end
			end
			if response
				http_live_list.push("http://#{ip}:#{port}")
				if ARGS[:verbose]
					puts "\nhttp://#{ip}:#{port}"
  					response.headers.each_header {|key,value| puts "#{key}: #{value}" }
  				end
			end
		end
	end
	return http_live_list
end

def server_checker_https(ip_lists, port_list)
	https_live_list = Array.new
	list = ip_table_builder(ip_lists)
	list.each do |ip|
		port_list.each do |port|
			begin
				response = HTTParty.get("https://#{ip}:#{port}", { timeout: 10 })
			rescue 
				if ARGS[:verbose]
  					$stderr.print "\nhttps://#{ip}:#{port} request failed"
  				end
			end
			if response
				http_live_list.push("https://#{ip}:#{port}")
				if ARGS[:verbose]
					puts "\nhttps://#{ip}:#{port}"
  					response.headers.each_header {|key,value| puts "#{key}: #{value}" }
  				end
			end
		end
	end
	return https_live_list
end

if ARGS[:http]
	live_list = server_checker_http(files, port_list)
end

if ARGS[:https]
	live_list = server_checker_https(files, port_list)
end

puts live_list
