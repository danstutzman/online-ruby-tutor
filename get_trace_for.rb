require 'pp'
require 'stringio'
require 'timeout'

class InstructionLimitReached < Exception
end

$___MAX_INSTRUCTIONS_LIMIT = 300
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
"
$___NUM_PREFIX_LINES = $___PREFIX.split("\n").size
$___SUFFIX = "
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
      if [Fixnum, NilClass, String, Symbol, TrueClass, FalseClass].include?(value.class)
        return value
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
    to_write_out = (binding.eval("$___to_output") rescue nil) || []
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
    if line > $___NUM_PREFIX_LINES && num_lines_over <= 1
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

def capture_stdout
  $stdout = StringIO.new
  yield
  return $stdout.string.clone
ensure
  $stdout = STDOUT
end

def ___get_trace_for_internal(___user_code)
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

  begin
    set_trace_func $___trace_func
    eval($___PREFIX + ___user_code + $___SUFFIX)
  ensure
    set_trace_func nil
  end
  nil
end

def get_trace_for(___user_code)
  $___user_code_num_lines = ___user_code.split("\n").size
  $___num_instructions_so_far = 0
  exception_frame = nil
  begin
    Timeout::timeout($___MAX_SECONDS_TO_COMPLETE) do
      Thread.start {
        $0 = $PROGRAM_NAME = "ruby" # for security
        ___user_code_changed = ___user_code.gsub(/^def ([a-z_])/, "def self.\\1")
        #puts ___user_code
        ___get_trace_for_internal(___user_code_changed)
      }.value
    end
  rescue Timeout::Error => e
    set_trace_func nil
    exception_frame = {
      'exception_msg' => "(timeout)",
      'event' => 'instruction_limit_reached',
    }
  rescue InstructionLimitReached => e
    exception_frame = {
      'exception_msg' => "(stopped after #{$___MAX_INSTRUCTIONS_LIMIT} steps to prevent possible infinite loop)",
      'event' => 'instruction_limit_reached',
    }
  rescue StandardError, SecurityError => e
    line_num = nil
    if e.backtrace && e.backtrace[1]
      line_num = e.backtrace[1].split(':')[1].to_i - $___NUM_PREFIX_LINES
    end
    exception_frame = $___traces.last.clone || {}
    exception_frame['exception_msg'] = "#{e} (#{e.class})"
    exception_frame['line'] = line_num
    exception_frame['event'] = 'uncaught_exception'
    exception_frame['offset'] = 1
  end
  {
    'code' => ___user_code + "\n''",
    'trace' => $___traces + (exception_frame ? [exception_frame] : []),
  }
end

if $0 == "get_trace_for.rb"
  pp get_trace_for("
class A
  def inspect
    \"test\"
  end
end
p A.new
b = lambda { |x|
  x + 3
}
def f(x)
end
puts f(5)
puts b.call(5)
")
end
