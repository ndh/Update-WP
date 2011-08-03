require 'rubygems'
require 'sequel'

VERBOSE = false

WP_CONFIG = ARGV.shift or abort "Usage: ruby update_wp_url.rb /path/to/wp-config.php"

puts "WP_CONFIG: '#{WP_CONFIG}'" if VERBOSE

db_name, db_user, db_password, db_host = nil

def get_val(line) 
  match = line.split(',').last
  
  match
    .gsub!(/'/, "")
    .gsub!(/\)/, "")
    .gsub!(/ /, "")
    .gsub!(/;/, "")
  
  return match
end

begin
  File.open(WP_CONFIG) do |io|
    io.each do |line|
      line.chomp!
      db_name = get_val(line) if line =~ /DB_NAME/
      db_user = get_val(line) if line =~ /DB_USER/
      db_password = get_val(line) if line =~ /DB_PASSWORD/
      db_host = get_val(line) if line =~ /DB_HOST/
    
      # stop reading the file as soon as we have our four values
      break if !db_name.nil? && !db_user.nil? && !db_password.nil? && !db_host.nil?    
    end
  end
rescue Errno::ENOENT
  puts "Error: file #{WP_CONFIG} does not exist."
	exit
end

# Do some database work
begin
  DB = Sequel.connect(:adapter => 'mysql', :user => db_user, :host => db_host, :database => db_name, :password=> db_password)
  
  puts DB.tables if VERBOSE
  
  search = '[url]'
  ds = DB.from(:wp_posts).select(:ID, :post_title).filter(:post_content.like("%#{search}%"))
  
  print "Found: #{ds.count} matches out of #{DB.from(:wp_posts).count} records for '#{search}'. Continue (Y/N) [N]? "
  confirmation = gets.chomp
  
  if confirmation == 'Y'
    print "What do you want to replace #{search} with? "
    new_value = gets.chomp
    update_sql = "UPDATE wp_posts SET post_content = replace(post_content, '#{search}', '#{new_value}')"
    
    print "About to run: #{update_sql}. Still good? (Y/N) [N] "
    confirmation_two = gets.chomp
    DB.run(update_sql) if confirmation_two == 'Y'
    puts "Update run."
  else
    puts "Whew, close call."
  end
  
rescue Sequel::DatabaseConnectionError => e
  puts "ERROR Found: #{e}"
end

puts "finis"
