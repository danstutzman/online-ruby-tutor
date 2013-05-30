require 'pp'
require 'stringio'
require 'timeout'

class InstructionLimitReached < Exception
end

$___MAX_INSTRUCTIONS_LIMIT = 500
$___MAX_SECONDS_TO_COMPLETE = 1

$___PREFIX = "
$___to_output = []
$___to_output.untrust
$___output = proc { |which_output, *args|
  $___to_output += [[which_output, args]]
  nil
}
module Kernel
  def puts( *___args); $___output.call(:puts,  *___args); end
  def p(    *___args); $___output.call(:p,     *(___args.map { |___arg| ___arg.inspect })); end
  def print(*___args); $___output.call(:print, *___args); end
end
module UserCode
end
UserCode.untrust
$SAFE = 4
module UserCode
begin
"
# Note: we'll define $___NUM_PREFIX_LINES later
$___SUFFIX = "
rescue => ___e
  ___e
end
end
"
$___NUM_SUFFIX_LINES = $___SUFFIX.split("\n").size

$___trace_func = proc { |event, file, line, id, binding, classname|
  #p [event, file, line, id]

  $___num_instructions_so_far += 1
  if $___num_instructions_so_far >= $___MAX_INSTRUCTIONS_LIMIT
    set_trace_func nil
    raise InstructionLimitReached
  end

  $___stack_to_render = $___stack_to_render[0..$___max_frame_id]

  if event == 'call' && file == '(eval)'
    $___max_frame_id += 1
    $___stack_to_render.push({
      "frame_id" => $___max_frame_id, 
      "encoded_locals" => nil, # fill out
      "is_highlighted" => nil, # fill out
      "is_parent" => false, 
      "func_name" => id.to_s,
      "is_zombie" => false, 
      "parent_frame_id_list" => [], 
      "unique_hash" => nil, # fill out
      "ordered_varnames" => nil, # fill out
    })
  end

  if event == 'return' && file == '(eval)'
    $___max_frame_id -= 1
    # trim it next time
  end

  if (event == 'line' || event == 'call' || event == 'return' || event == 'end') && file == '(eval)'
    #printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
    
    heap = {}
    def represent_value(value, heap)
      if [Fixnum, NilClass, Symbol,
          TrueClass, FalseClass, Float].include?(value.class)
        return value
      elsif String === value
        return value.clone
      elsif [Array, Hash, Proc].include?(value.class)
        on_heap = case value
          when Array
            ["LIST"] + value.map { |element|
              represent_value(element, heap)
            }
          when Hash
            ["DICT"] + value.map { |key, val|
              [represent_value(key, heap),
               represent_value(val, heap)]
            }
          when Proc
            ["FUNCTION", "line #{value.source_location[1] - $___NUM_PREFIX_LINES}", nil]
        end
        heap[value.object_id] = on_heap
        return ['REF', value.object_id]
      else
        #puts "Don't know type #{value.class}"
        value.class.to_s
      end
    end

    locals = binding.eval('local_variables')
    local_values = {}
    locals.reject! { |local_name| local_name.to_s.start_with?('___') }
    locals.each do |local_name|
      value = binding.eval(local_name.to_s)
      local_values[local_name.to_s] = represent_value(value, heap)
    end

    if $___stack_to_render.last
      $___stack_to_render.last['encoded_locals'] = local_values.clone
      $___stack_to_render.last['ordered_varnames'] = locals.clone
      $___stack_to_render.last['is_highlighted'] = (event == 'call')
      $___stack_to_render.last['unique_hash'] = id.to_s
    end

    stdout = StringIO.new
    to_write_out = binding.eval("$___to_output") || []
    to_write_out.each do |which_output_and_args|
      which_output, args = which_output_and_args
      if which_output == :puts
        stdout.puts(*args)
      elsif which_output == :p
        stdout.puts(*args)
      elsif which_output == :print
        stdout.print(*args)
      end
    end
  
    num_lines_over = (line - $___NUM_PREFIX_LINES) - $___user_code_num_lines
    if line > $___NUM_PREFIX_LINES && num_lines_over < $___NUM_SUFFIX_LINES + 1
      trace = {
        'ordered_globals' => [],
        'stdout' => stdout.string.clone,
        'func_name' => 'main',
        'stack_to_render' => $___stack_to_render.map { |frame| frame.clone },
        'globals' => {},
        'heap' => heap,
        'line' => (num_lines_over > 0) ? $___user_code_num_lines : (line - $___NUM_PREFIX_LINES),
        'event' => 'step_line',
      }
      $___traces.push trace
    end
  end
}

def ___get_trace_for_internal(___system_code, ___user_code, ___assignments)
  $___traces = []
  $___max_frame_id = 0
  $___stack_to_render = [{
    "frame_id" => $___max_frame_id, 
    "encoded_locals" => nil, # fill out
    "is_highlighted" => nil, # fill out
    "is_parent" => false, 
    "func_name" => '<main>',
    "is_zombie" => false, 
    "parent_frame_id_list" => [], 
    "unique_hash" => "foo_f0", 
    "ordered_varnames" => nil, # fill out
  }]

  ___assignment_line = ___assignments.map {
    |___assignment_key, ___assignment_value|
    "#{___assignment_key} = #{___assignment_value.inspect}"
  }.join('; ') + "\n"

  $___NUM_PREFIX_LINES = $___PREFIX.split("\n").size + 1 # + 1 for assignments
  $___NUM_PREFIX_LINES += ___system_code.split("\n").size

  begin
    set_trace_func $___trace_func
    eval(
      $___PREFIX +
      ___system_code +
      ___assignment_line +
      ___user_code +
      $___SUFFIX
    )
  ensure
    set_trace_func nil
  end
end

def get_trace_for_case(___system_code, ___user_code, ___assignments)
  $___user_code_num_lines = ___user_code.chomp.split("\n").size
  $___num_instructions_so_far = 0
  begin
    returned = nil
    Timeout::timeout($___MAX_SECONDS_TO_COMPLETE) do
      returned = Thread.start {
        $0 = $PROGRAM_NAME = "ruby" # for security
        ___user_code_changed = ___user_code.gsub(/^def ([a-z_])/, "def self.\\1")
        #puts ___user_code
        ___get_trace_for_internal(
          ___system_code, ___user_code_changed, ___assignments)
      }.value
    end
    if Exception === returned
      raise returned
    end
  rescue Timeout::Error => e
    set_trace_func nil
    $___traces.push({
      'exception_msg' => "(timeout)",
      'event' => 'instruction_limit_reached',
    })
    returned = e
  rescue InstructionLimitReached => e
    $___traces.push({
      'exception_msg' => "(stopped after #{$___MAX_INSTRUCTIONS_LIMIT} steps to prevent possible infinite loop)",
      'event' => 'instruction_limit_reached',
    })
    returned = e
  rescue StandardError, SecurityError, SyntaxError => e
    line_num = nil
    exception_msg = "#{e} (#{e.class})"
    if match = e.to_s.match(/\(eval\):([0-9]+):(.*)/)
      line_num = match[1].to_i - $___NUM_PREFIX_LINES
      if line_num > $___user_code_num_lines
        line_num = $___user_code_num_lines
      end
 
      # fudge the line number
      exception_msg = e.to_s.gsub(":#{match[1]}:", ":#{line_num}:")
      exception_msg = "#{exception_msg} (#{e.class})"
    elsif e.backtrace && e.backtrace[0] &&
      match = e.backtrace[0].match(/\(eval\):([0-9]+):in `<module:UserCode>'/)
      line_num = match[1].to_i - $___NUM_PREFIX_LINES
      exception_msg += " at line #{line_num}"
    elsif e.backtrace && e.backtrace[1] &&
      match = e.backtrace[1].match(/\(eval\):([0-9]+):in `<module:UserCode>'/)
      line_num = match[1].to_i - $___NUM_PREFIX_LINES
      exception_msg += " at line #{line_num}"
    end

    exception_msg.gsub!(
      /^uninitialized constant UserCode::([^ ]+) \(NameError\)/,
      'uninitialized constant \\1 (NameError)')

    $___traces.push({}) if $___traces.size == 0
    exception_frame = $___traces.last
    exception_frame['exception_msg'] = exception_msg
    exception_frame['line'] = line_num
    exception_frame['event'] = 'uncaught_exception'
    exception_frame['offset'] = 1
    if exception_frame['ordered_globals'].nil?
      exception_frame['ordered_globals'] = []
    end
    if exception_frame['stack_to_render'].nil?
      exception_frame['stack_to_render'] = {}
    end
    returned = e
  end
  {
    'code' => ___user_code,
    'trace' => $___traces,
    'returned' => returned,
  }
end

def get_trace_for_cases(___system_code, ___user_code, ___cases)
  ___cases.map { |___assignments|
    get_trace_for_case(___system_code, ___user_code, ___assignments)
  }
end

CLASS_NAME_REGEX = /^[A-Z][A-Za-z0-9_]*$/
COLUMN_NAME_REGEX = /^[a-z][a-z0-9_]*$/
def fake_active_record_class_definition(class_name, column_name_to_type,
    validates_presence_of_column_names)
  if !CLASS_NAME_REGEX.match(class_name)
    raise "Class name #{class_name} doesn't match regex #{CLASS_NAME_REGEX}"
  end

  methods = []

  initialize_method = "  def initialize
    @attributes = {}
    @errors = []
  "
  column_name_to_type.each do |name, type|
    initialize_method += "    @attributes[:#{name}] = nil\n"
  end
  initialize_method += "  end"
  methods.push(initialize_method)

  column_name_to_type.each do |name, type|
    if !COLUMN_NAME_REGEX.match(name)
      raise "Column name #{name} doesn't match regex #{COLUMN_NAME_REGEX}"
    end
    if type == Fixnum
      methods.push "  def #{name}
    @attributes[:#{name}]
  end"
      methods.push "  def #{name}=(new_value)
    @attributes[:#{name}] = (new_value == nil) ? nil : new_value.to_i
  end"
    elsif type == String
      methods.push "  def #{name}
    @attributes[:#{name}]
  end"
      methods.push "  def #{name}=(new_value)
    @attributes[:#{name}] = (new_value == nil) ? nil : new_value.to_s
  end"
    elsif type == TrueClass
      methods.push "  def #{name}
    @attributes[:#{name}]
  end"
      methods.push "  def #{name}=(new_value)
    @attributes[:#{name}] = case new_value
      when nil then nil
      when '' then nil
      when true then true
      when 't' then true
      when 'T' then true
      when 'true' then true
      when 'TRUE' then true
      else false
    end
  end"
    else
      raise "Unknown type for column name #{name}"
    end
  end

  inspect_method = %Q[  def inspect
    pairs = @attributes.map { |key, value| "\#{key}: \#{value.inspect}" }
    "#<#{class_name} " + pairs.join(", ") + ">"
  end]
  methods.push inspect_method

  valid_question_method = "  def valid?\n"
  valid_question_method += "    @errors = []\n"
  validates_presence_of_column_names.each do |name|
    valid_question_method +=
      "    if @attributes[:#{name}] == nil || @attributes[:#{name}] == ''\n"
    valid_question_method += "      @errors.push \"#{name} can't be blank\"\n"
    valid_question_method += "    end\n"
  end
  valid_question_method += "    @errors.size == 0\n"
  valid_question_method += "  end"
  methods.push valid_question_method

  save_method = "  def save
    if valid?
      if @attributes[:id].nil?
        @attributes[:id] = 1
      end
      true
    else
      false
    end
  end"
  methods.push save_method

  save_bang_method = "  def save!
    self.save or raise(\"ActiveRecord::RecordInvalid: Validation failed: \" + @errors.join(', '))
  end"
  methods.push save_bang_method

  where_method  = "  def self.where(conditions)\n"
  where_method += "    results = []\n"
  # synthesize some data
  where_method += "    result = #{class_name}.new\n"
  column_name_to_type.each do |name, type|
    if type == Fixnum
      where_method += "    result.#{name} = 9\n"
    elsif type == String
      where_method += "    result.#{name} = 'abc'\n"
    elsif type == TrueClass
      where_method += "    result.#{name} = true\n"
    else
      raise "Unknown type for column name #{name}"
    end
  end
  where_method += "    result.save\n"
  where_method += "    results.push result\n"
  where_method += "    results\n"
  where_method += "  end"
  methods.push where_method

  all_method = "  def self.all
    self.where({}).all
  end"
  methods.push all_method

  first_method = "  def self.first
    self.where({}).first
  end"
  methods.push first_method

  return "class #{class_name}\n" + methods.join("\n") + "\n  end\n"
end

if $0 == "get_trace_for.rb"
  class_def = fake_active_record_class_definition("GardenPlot", {
    id: Fixnum,
    planted_year: Fixnum,
    seed_type: String,
    is_unused: TrueClass,
  }, [:seed_type])
  puts class_def
  pp get_trace_for_cases(class_def,
"thing = GardenPlot.new
thing.planted_year = '3'
thing.seed_type = ''
thing.is_unused = true
puts GardenPlot.first.inspect
", [{}])
end
