require "csv"
require "google/apis/civicinfo_v2"
require "erb"

# More succint version of clean_zipcode
def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  # probably a good idea to get rid of everything that is not a number ("-", etc)
  phone_number = phone_number.split("-")

  # if phone is less than 10 digits, assume it's a bad number
  if phone_number.length < 10
    phone_number = "0000000000"
  # if phone is 10 digits, assume it's good
  elsif phone_number.length == 10
    phone_number
  # if phone is 11 digits and the first number is 1, trim the 1 and u se the remaining 10 digits
  elsif phone_number.length == 11
    if phone_number[0] == "1"
      phone_number.slice(1..-1)
    # if phone is 11 digits and the first number is not 1, then it's a bad number
    # if the phone number is more than 11 digits, assume it's a bad number
    else
      phone_number = "0000000000"
    end
  end
end

# Isolate registration hour
def registration_date_format(regdate)
   # regdate has two values, date and time, separated by a " "  
  regdate_array = regdate.split(" ")
  if regdate_array.length == 2
    date_string = regdate_array[0].split("/")
    month = date_string[0]
    day = date_string[1]
    year = "20" + date_string[2]
    # date_object = Date.new(year, month, day)

    time_string = regdate_array[1].split(":")
    hour = time_string[0]
    minutes = time_string[1]
    time_object = Time.new(year, month, day, hour, minutes)
    time_object
  end

end

# Find peak registration hours
def find_peak_registration_hours(time_object_array)
  # hours hash, key should be the hour in 24h format, value should be how many times that hour is present
  
  # Initialize hours hash, with the 24 hour values, to 0
  hours = {}
  24.times do |i|
    hours[i] = 0
  end
  

  time_object_array.each do |time_obj|
    hours[time_obj.hour] += 1
  end

  # Find max value and output
  highest_count_value = hours.values.max
  peak_hour = hours.key(highest_count_value)
  puts "Peak registration hour is #{peak_hour}:00"
  peak_hour
end

# Find peak day of the week
def find_peak_day_of_week(time_object_array)
  # Initialize hash with default value of 0 for non-existing keys
  days = Hash.new(0)
  
  time_object_array.each do |obj|
    days[obj.wday] += 1
  end

  # What key has the highest value?
  max_day = days.max_by { |key, value| value }.first

  max_day_string = case max_day
    when 0 then "Sunday"
    when 1 then "Monday"
    when 2 then "Tuesday"
    when 3 then "Wednesday"
    when 4 then "Thursday"
    when 5 then "Friday"
    when 6 then "Saturday"
  end

  puts "Day of the week with highest number of registrations is #{max_day_string}"
  
end


def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = "AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw"

  begin
    legislators = civic_info.representative_info_by_address(

    address: zip,
    levels: "country",
    roles: ["legislatorUpperBody", "legislatorLowerBody"]  
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end  
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir("output") unless Dir.exist?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end


puts "Event Manager Initialized!"

if File.exist? "event_attendees.csv"
  contents = CSV.open(
    "event_attendees.csv",
    headers: true,
    header_converters: :symbol
  )

  template_letter = File.read("form_letter.erb")
  erb_template = ERB.new template_letter
  
  registration_dates = []

  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    legislators = legislators_by_zipcode(zipcode)
    # phone numbers
    phone_number = clean_phone_number(row[:homephone])
    # registration_dates array will collect all the registration_date time objects
    registration_date = registration_date_format(row[:regdate])
    registration_dates.push(registration_date)

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id, form_letter)
  end

  find_peak_registration_hours(registration_dates)
  find_peak_day_of_week(registration_dates)

end
  