require './web-app.rb'
ActiveRecord::Base.logger = nil
puts "require './web-app.rb'"
Exercise.order(:id).each do |exercise|
  attributes = exercise.attributes
  attributes['created_at'] = attributes['created_at'].to_s
  attributes['updated_at'] = attributes['updated_at'].to_s
  puts "Exercise.create!(#{attributes.inspect})"
end
