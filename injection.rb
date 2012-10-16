require "#{Rails.root}/app/models/m_v.rb"
require "#{Rails.root}/lib/peak_finder.rb"

class Injection < ActiveRecord::Base
  # FID = {:compound => 'fid', :time_window => 3.minutes}
  # ECD = {:compound => 'ecd', :time_window => 5.minutes}

  belongs_to :incubation

  def self.has_mv?
    MV.where(:datetime => self.sampled_at).first.nil?
  end

  def ecd_marked_with_time
    records = ecd_with_time
    # don't try to mark peaks if the start and end has not been set
    if self.n2o_peak_start and self.n2o_peak_end
      mark_peaks(records, n2o_peak_start, n2o_peak_end)
    else
      records
    end
  end

  def ecd_with_time
    return [] unless incubation
    records = mv_with_time(incubation.ecd_peak_window_start..incubation.ecd_peak_window_end)
    records.collect {|x| {:datetime => x.datetime, :mv => x.ecd}}
  end

  def ecd
    records = mv(incubation.ecd_peak_window_start..incubation.ecd_peak_window_end)
    records.collect {|x| {:mv => x.ecd}}
  end

  def fid_marked_with_time
    records = fid_with_time
    # don't try to mark peaks if the start and end has not been set
    if self.ch4_peak_start and self.ch4_peak_end
      mark_peaks(records, ch4_peak_start, ch4_peak_end)
    else
      records
    end
  end

  def fid_with_time
    return [] unless incubation
    records = mv_with_time(incubation.fid_peak_window_start..incubation.fid_peak_window_end)
    records.collect {|x| {:datetime => x.datetime, :mv => x.fid}}
  end

  def fid
    records = mv(incubation.fid_peak_window_start..incubation.fid_peak_window_end)
    records.collect {|x| {:mv => x.fid}}
  end

  def mv_with_time(time_window)

    MV.where(:site_id => incubation.site_id)
      .where(:datetime => sampled_at + time_window.first.minutes .. sampled_at + time_window.last.minutes).order(:datetime)
  end

  def mv(time_window)
    MV.where(:site_id => incubation.site_id)
      .where(:datetime => (sampled_at + time_window.first.minutes)..(sampled_at + time_window.last.minutes)).order(:datetime).all
  end

  def prep_ecd
    data = ecd_with_time
    times = data.collect {|x| x[:datetime]}
    mv = data.collect {|x| x[:mv]}
    [mv,times]
  end

  def prep_fid
    data = fid_with_time
    times = data.collect {|x| x[:datetime]}
    mv = data.collect {|x| x[:mv]}
    [mv,times]
  end


  def ecd_to_csv(filename='mv.csv')
    data = prep_ecd
    CSV.open(filename,'w') do |csv|
      csv << ['mv','date']
      data.transpose.each do |d|
        csv << d
      end
    end
  end

  def fid_to_csv(filename='fid.csv')
    data = prep_fid
    CSV.open(filename,'w') do |csv|
      csv << ['mv','date']
      data.transpose.each do |d|
        csv << d
      end
    end
  end

  def mark_peaks(data, start, finish)
    data.each do |d|
      d[:peak] = d[:datetime] > start && d[:datetime] < finish
    end
    data
  end

  def integrate_drop_baseline(peak_data)
    volts      = peak_data.collect {|x| x[:mv] }
    # The minimum voltage should always be and one end or the other of the peak.
    adj_volts  = volts.collect {|x| x - volts.min }
    adj_volts.inject(:+)
  end

  def integrate_skim(peak_data)
    volts      = peak_data.collect {|x| x[:mv] }
    # The minimum voltage should always be and one end or the other of the peak.
    adj_volts  = volts.collect {|x| x - volts.min }
    total_area = adj_volts.inject(:+)

    bounds          = [peak_data.first,peak_data.last]
    min             = bounds.min {|a,b| a[:mv] <=> b[:mv] }
    max             = bounds.max {|a,b| a[:mv] <=> b[:mv]} 
    base_triangle   = (max[:mv] - volts.min * peak_data.size)/2

    total_area - base_triangle
  end

  def find_fid_peaks
    volt = fid_with_time
    unless volt.empty?
      unless volt[0][:mv].nil?
        find_peak(volt, volt[0][:datetime], 320, 0)
      end
    end
  end
  # This method calls peak_finder_fid to find peaks using the modified
  # peak finder algorithm. It is only used to find methane peaks.
  # returns: an array of hashes [{:mv => millivolts, :datetime => times},...,{}]
  # of peak mvs and corresponding datetimes
  def find_fid_peaks2
    volt = fid_with_time
    unless volt.empty?
      unless volt[0][:mv].nil?
        peak_finder_fid(volt)
      end
    end
  end

  def find_ecd_peaks

    volt = ecd_with_time
    unless volt.empty?
      unless volt[0][:mv].nil?
        # find the maximum in the first half of the peak window
        max = volt[0..volt.size/2].max {|a,b| a[:mv] <=> b[:mv]} 
        peak_window_start = max[:datetime] + incubation.offset

        find_peak(volt, peak_window_start, 30, 500)
      end
    end
  end
  # This method calls peak_finder_ecd to find peaks using the modified
  # peak finder algorithm. It is only used for nitrous oxide peaks.
  # returns: an array of hashes [{:mv => millivolts, :datetime => times},...,{}]
  # of peak mvs and corresponding datetimes
  def find_ecd_peaks2
    volt = ecd_with_time
    unless volt.empty?
      unless volt[0][:mv].nil?
        peak_finder_ecd(volt)
      end
    end
  end

  def find_peak(volt, peak_window_start=0, window_size=30, threshold=0)
	
    # find the maximum in the window_size seconds after the offset
    peak_top_record =  volt.select {|a| peak_window_start < a[:datetime] && 
      peak_window_start + window_size > a[:datetime] }.max {|a,b| a[:mv] <=> b[:mv]}

    if peak_top_record
      peak_top_index = volt.index(peak_top_record)
      peak_data = []
      diff = last_diff = 0
      # find the front peak start
      peak_top_index.downto(1) do |i|
        peak_data << volt[i]
        diff = volt[i][:mv] - volt[i-1][:mv]
        # but only if the slope is decreasing
        if diff < last_diff
          break if diff <= threshold
        end
        last_diff = diff
      end

      # find the peak end 
      # save the beginning peak voltage to be able to increate the cutoff once the baseline
      # drops below the initial baseline
      peak_data = peak_data.sort {|a,b| a[:datetime] <=> b[:datetime] }
      first_point = peak_data[0]
      diff = last_diff = 0
      (peak_top_index+1).upto(volt.size-1) do |i|
        peak_data << volt[i]
        diff = volt[i][:mv] - volt[i-1][:mv]
        # but only f the slope is decreasing
        if diff.abs < last_diff.abs
          break if diff >= (first_point[:mv] <  volt[i][:mv] ? 0 : -i * threshold)
        end
      end
      peak_data.sort {|a,b| a[:datetime] <=> b[:datetime] }
    end
  end

  def find_peaks_by_second_differential
    # compute first differential
    1.upto(volt.size-1) do |i|
      volt[i][:first_diff] = volt[i][:mv] - volt[i-1][:mv]
    end
    #compute second differential
    1.upto(volt.size-1) do |i|
      volt[i][:second_diff] = volit[i][first_diff] - volt[i-1][:first_diff]
    end

    # find the maximum in the window_size seconds after the offset
    peak_top_record =  volt.select {|a| peak_window_start < a[:datetime] && 
      peak_window_start + window_size > a[:datetime] }.max {|a,b| a[:mv] <=> b[:mv]}

    if peak_top_record
      peak_top_index = volt.index(peak_top_record)
      peak_data = []
      # find the front peak start
      peak_top_index.downto(1) do |i|
        peak_data << volt[i]
        break if volt[i][:second_diff] - volt[i-1][:second_diff] >= 0
      end
      # find the peak end 
      # TODO what if they maximum is on the downside of the peak.
      (peak_top_index+1).upto(volt.size-1) do |i|
        peak_data << volt[i]
        break if volt[i][:second_diff] - volt[i-1][:second_diff] >= 0
      end
      peak_data.sort {|a,b| a[:datetime] <=> b[:datetime] }
    end
  end

  # # # # # # # # # # # # Method: peak_finder_fid # # # # # # # # # # # # # # # # # # # 
  # This method is the callee of find_fid_peaks2. It uses numerical differentiation
  # to find the peak beginning. This value is becomes a baseline, and is used to 
  # locate the end of the desired peak. The variable trend is used to ignore irrelevant 
  # oscillations that may occur during the peak.
  # (Three consecutive negative slopes constitute a trend)
  # Note: The value of 500 has been hardcoded, as it seems
  # to be effective. This value can be set manually if necessary. NWD
  # param volt-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the injection period
  # return peak_array[0]-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the peak
  #####################################################################################
  def peak_finder_fid(volt)
    diff = []
    peak_array = []
    peak_found = false # is true when desired CH4 peak is found
		peak_dec = false   # is true when the peak slope begins decreasing
    trend = 0
    # an array of hashes
    for i in 1..(volt.size - 1)
      diff[i] = volt[i][:mv] - volt[i-1][:mv]
      # looking for a rate of change of > 500, which typifies a peak beginning
			if ((diff[i] > 500) and (peak_found == false))
				vs = i - 1
				base = volt[vs][:mv]
				peak_found = true	
			end
      # if a peak has been found, then start looking for its descent
			if ((peak_found == true) and (diff[i] < 0)) 
				# want to ignore trends to find real descent
        if (trend < 2) 
					trend = trend + 1
				else
				  # a trend has been established; peak is decreasing
					peak_dec = true
				end			
			# want to find a trend of three dec. slopes in a row; else reset trend count to zero
			elsif  ((peak_found == true) and (diff[i] > 0)) 
					trend = 0 #reset trend
			end
			# if true than the peak end has been established
			if ((peak_dec == true) and (volt[i-1][:mv] <= base))
				# We have found the desired peak end point	
				ve = i - 1
        temp_peak = volt[vs..ve] # put peak interval into a new array
        peak_array << temp_peak  
        # reset booleans to check for more peaks
				peak_found = false
				peak_dec = false
			end # if dip below base volt
    end # end big for loop
    # If more than one peak found, inform user.
    if (peak_array.size > 1)
      puts "More than one peak found."
    end
    return peak_array.first # there should only be one peak per injection
  end # end method fid

  # # # # # # # # # # # # Method: peak_finder_ecd # # # # # # # # # # # # # # # # # # # 
  # This method is the callee of find_ecd_peaks2. It uses numerical differentiation
  # to find the beginning of a peak. This value is becomes a baseline, and is used to 
  # locate the end of the desired peak.
  # Note: The values of 10000 and 3000 have currently been hardcoded, as they seem
  # to be effective. These values can be set manually if necessary. NWD
  # param volt-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the injection period
  # return peak_array[0]-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the peak
  #####################################################################################
  def peak_finder_ecd(volt)
    diff = []
    peak_array = []
    peak_found = false # is true when desired N20 peak is found
		peak_dec = false # is true when desired N20 peak descends
    big_peak = false # is true when start of big peak is found
		big_peak_decrease = false # is true when big peak slope begins decreasing
		trend = 0
    # an array of hashes
    for i in 1..(volt.size - 1)
        diff[i] = volt[i][:mv] - volt[i-1][:mv]
        # looking for a rate of change of > 10000, which typifies a peak beginning
				if ((diff[i] > 10000) and (big_peak == false) and (peak_found == false))
				  big_peak = true
			  end
			  # if the big peak has been found, then start looking for its descent
				if ((big_peak == true) and (diff[i] < 0))
				  # want to ignore trends to find real descent
          if (trend < 2) 
					  trend = trend + 1
				  else
				    # a trend has been established; big peak is decreasing
					  big_peak_decrease = true
				  end	
				# want to find a trend of three dec. slopes in a row; else reset trend count to zero
			  elsif ((big_peak == true) and (diff[i] > 0))
				  	trend = 0 # reset trend
		  	end
			  # The big peak declination has been found.
				# When it increases we know that the desired peak has been found.
        # The value of 3000 is used to ignore insignificant fluxuations
				if ((big_peak_decrease == true) and (diff[i] > 3000) and (peak_found == false)) 
					# We have found the desired peak start point
					vs = i - 1
					base = volt[vs][:mv] # set baseline to find peak end
					peak_found = true
				end
			  # when the peak starts decreasing we must start looking for the end of the peak
				if ((peak_found == true) and (diff[i] < 0))
					peak_dec = true
				end
			  # if true than peak has bottomed out
				if ((peak_dec == true) and (volt[i-1][:mv] <= base)) 
					ve = i - 1 # We have found the desired peak end point
					temp_peak = volt[vs..ve] # put peak interval into a new array
				  peak_array << temp_peak
				  # reset all booleans; begin the search for the next peak pair
					big_peak = false
					big_peak_decrease = false
					peak_dec = false
					peak_found = false
				end # end if below base
			end # end volt loop
			# If more than one peak found, inform user.
			if (peak_array.size > 1)
        puts "More than one peak found."
      end
      return peak_array.first # there should only be one peak per injection
	end # end method ecd

  def find_peaks2(compound)
    peak_data = []
    diff = []
    tolerance = 1000
    big_peak = false # is true when start of big peak found
    big_peak_decrease = false # is true when big peak descends
    found = false # is true when desired N20 peak is found
    decrease = false # is true when desired N20 peak descends

    volt = ecd_with_time
    for i in 1..(volt.size - 1)

      diff[i] = volt[i-1][:mv] - volt[i][:mv]

      big_peak = true if diff[i] > 2000 and not big_peak and not found
      big_peak_decrease = true if big_peak and diff[i] < 0

      if big_peak_decrease and diff[i] > tolerance and not found
        vs = i - 1
        found = true
      end
      decrease = true if found and diff[i] < 0

      if decrease and diff[i] > tolerance
        ve = i - 1
        peak_data << volt[vs..ve]

        # reset all booleans; begin the search for the next peak pair
        big_peak = false
        big_peak_decrease = false
        decrease = false
        found = false
      end
    end
    peak_data
  end
  
end
