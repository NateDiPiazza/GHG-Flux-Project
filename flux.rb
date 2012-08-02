require 'pg'
require 'dbi'

# Flux.rb#####################################################################
# Author: Nathan DiPiazza
# Company: GLBRC
# Module 5
#
# This program calculates the flux for each injection of an 
# entire run(for ch4, n2o, and co2),using the concentrations 
# produced by module 4. The data is then entered into the 
# incubations datatable. A run flag = 2 means that the ppm values have
# been calculated and the flux can be found. Flag is set to 3 after values
# have been updated in DB
# 
# Command line parameters: 
# 0: database name
# 1: username
# 2: password
##############################################################################

# Global Variables ###########################################################
ch4 = [] # hold ch4 ppms    from injections
n2o = [] # hold n20 ppms    from injections
co2 = [] # hold sample ppms from licor_samples
times = []    # sampled_at times
ids = []      # primary key to update data table
run_id_array = [] # array to store appropriate run ids
chamber = []
mol_weight = Hash.new # the keys for this hash will be the gas names
a = 0 # slope in ppm/min
##############################################################################

# validation block
if ARGV.size > 3
   puts "Usage: Too many command line arguments. Quitting"
   exit
end
if ARGV.size == 0
   puts "Usage: No command line arguments given. Quitting"
   exit
end
if (ARGV.size == 1) || (ARGV.size == 2)
   puts "Usage: Three command line arguments are required. Quitting"
   exit
end

db_name = ARGV[0] 
user_name = ARGV[1] 
pass = ARGV[2] 
#run_id = ARGV[3] 

dbh = DBI.connect("DBI:Pg:#{db_name}", user_name, pass)

# and 'c' from database molecular_weight (these values are constant)
comp_db = dbh.execute("SELECT name, mol_weight FROM compounds")
while row = comp_db.fetch do
   # molecular weights (g/mol)
   mol_weight[row[0]] = row[1]
end
comp_db.finish

# processed = 2 means that the ppms have been computed, limit set to 500 to keep speed up.
runs_db = dbh.execute("SELECT runs.id FROM runs JOIN injections ON injections.run_id = runs.id WHERE runs.processed = 2 LIMIT 500")
print "Processing "
while row = runs_db.fetch do
   run_id_array << row[0]
end
# If zero rows are returned from query then processing is up to date.
if run_id_array.empty?
   puts ""
   puts "There are currently no runs to process. Quitting."
   exit
end
run_id_array.uniq!
# big loop to go through all unprocessed runs (LIMIT 500)
for r in 0..(run_id_array.size - 1)
   run_id = run_id_array[r]
   # select concentrations and injection times from db for one run
   flux_db = dbh.execute("SELECT injections.ch4_ppm, injections.n2o_ppm, injections.co2_ppm, injections.sampled_at, incubations.id, incubations.chamber FROM injections JOIN incubations ON injections.run_id = incubations.run_id WHERE injections.run_id = #{run_id}")

#flux_db = dbh.execute("SELECT injections.ch4_ppm, injections.n2o_ppm, licor_samples.co2_ppm, injections.sampled_at, incubations.id FROM injections JOIN incubations ON injections.id = incubations.id join licor_samples on incubations.id = licor_samples.incubation_id where injections.run_id = #{run_id}")

   while row = flux_db.fetch do
       ch4 << row[0]
       n2o << row[1]
       co2 << row[2]
       times << row[3]
       ids   << row[4]
      chamber << row[5]
   end
   run_array = [ch4, n2o, co2, times, ids, chamber]
   
   # loop through to  update all incubations with flux values
   for j in 0..(run_array.size - 1) do
      # loop to handle the three gases
      for i in 0..2 do
         # selects the current gas
         if i == 0
            c = mol_weight['ch4']
            gas_type = 'ch4_flux'
            a = run_array[0][j]
         elsif i == 1
            c = mol_weight['n2o']
            gas_type = 'n2o_flux'
            a = run_array[1][j]
         else
            c = mol_weight['co2']
            gas_type = 'co2_flux'
            a = run_array[2][j]
         end
         # if a is null than there is no concentration for this flux
         if a.nil? == false
            # Chamber & time
            t = run_array[3][j]
            cr = run_array[5][j]
            # pull 'b' (headspace) form database
            deploy_db = dbh.execute("select height from deployments where '#{t}' between deployed_on and removed_on and chamber = '#{cr}'") # Query assumes that latest entry contains the current values
            row = deploy_db.fetch 
            b = row[0] # headspace volumeof the container (Liters)
            deploy_db.finish
            # Validation to ensure that headspace height measurement exists in DB
            if b.nil?
               puts "Error: No headspace height found for chamber: #{cr}, at time: #{t}.\nPlease check deployments datatable."
               exit
            end
            # incubation id
            i_id = run_array[4][j]	
            # formula to convert ppm/min to grams of compound per hectare per day
            #f = a * b * (1/745) * 10000 * 10000 * 60 * 24 * (1/22.4) * c * (1/1000) * (1/1000)
            f = (a * b * c * (9000/1043)) # simplified
            # Update the incubations data table
            dbh.do("UPDATE incubations SET #{gas_type} = #{f}, sampled_at = '#{t}' WHERE id = #{i_id}")
         end # end nil check
      end # for i
   end # end j
   dbh.do("UPDATE runs SET processed = 3 WHERE id = #{run_id}")
      if (run_id % 5) == 0
             print ". "
      end # end run_id %
end # runs loop for r
puts ""
puts "flux values successfully added!"
# end of program
