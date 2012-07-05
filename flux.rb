require 'pg'
require 'dbi'



db_name = ARGV[0] # gasflux
user_name = ARGV[1] # gasflux
pass = ARGV[2] # g@sf1ux
  
dbh = DBI.connect("DBI:Pg:#{db_name}", user_name, pass)
    
gas = ARGV[3] # ecd or fid
run_id = ARGV[4] # 5864 or anything

#TODO add code to parse gas types for insert later


#TODO add loop to go through by each gas

# select concentrations and injection times from db
# TODO first stab at query =) ;) :)
# I think there should be four rounds of 8 peaks ???
flux_db = dbh.execute("SELECT peak_area, peak_concentration, peak_start FROM injections WHERE run_id = #{run_id}")

while row = flux_db.fetch do
    # add code
    # run_blah = row[some number]
    # run_array << run_blah
end

for i in 0..(run_array.size - 1) do
	# maybe i could be used for time here???
	# convert start time to # of seconds; convert to min.

	# apply formula to get flux

	a = 0 # slope in ppm/min
	b = 0 # headspace volumeof the container (Liters)
	c = 0 # molecular weight

	# formula to convert ppm/min to grams of compound per hectare per day
	f = a * b * (1/745) * 10000 * 10000 * 60 * 24 * (1/22.4) * c * (1/1000) * (1/1000)

	# Insert data into incubations table; loop through first by gas type, lastly by chamber start_time
        # EXAMPLE OF UPDATE QUERY update incubations set ch4_flux=some_flux_val where id=some_num;
	rows = dbh.do("insert into incubations(" + gas_flux_type + ", sampled_at) values (#{f}, #{start_time})")

end
