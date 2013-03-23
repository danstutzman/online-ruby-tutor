require 'pp'
require 'stringio'

$___PREFIX = "
$___to_puts = []
$___to_p = []
$___to_print = []
$___to_puts.untrust
$___to_p.untrust
$___to_print.untrust
$___puts  = proc { |*args| $___to_puts  += [args]; nil }
$___p     = proc { |*args| $___to_p     += [args]; nil }
$___print = proc { |*args| $___to_print += [args]; nil }
module Kernel
  def puts( *args); $___puts.call( *args); end
  def p(    *args); $___p.call(    *args); end
  def print(*args); $___print.call(*args); end
end
class UserCode
end
UserCode.untrust
$SAFE = 4
class UserCode
  def ___go
"
$___NUM_PREFIX_LINES = $___PREFIX.split("\n").size
$___SUFFIX = "
''
end
end
UserCode.new.___go
"
$___NUM_SUFFIX_LINES = $___SUFFIX.split("\n").size

$___trace_func = proc { |event, file, line, id, binding, classname|
  #p [event, file, line, id]

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

  if (event == 'line' || event == 'call' || event == 'return') && file == '(eval)'
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
        puts "Don't know type #{value.class}"
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
    to_write_out = (binding.eval("$___to_puts") rescue nil) || []
    to_write_out.each { |to_write| stdout.puts(*to_write) }
    to_write_out = (binding.eval("$___to_p") rescue nil) || []
    to_write_out.each { |to_write| stdout.puts(*(to_write.map { |thing| thing.inspect })) }
    to_write_out = (binding.eval("$___to_print") rescue nil) || []
    to_write_out.each { |to_write| stdout.print(*to_write) }
  
    if line > $___NUM_PREFIX_LINES && (line - $___NUM_PREFIX_LINES <= ($___user_code_num_lines + 2))
      trace = {
        'ordered_globals' => [],
        'stdout' => stdout.string.clone,
        'func_name' => 'main',
        'stack_to_render' => $___stack_to_render.map { |frame| frame.clone },
        'globals' => {},
        'heap' => heap,
        'line' => line - $___NUM_PREFIX_LINES,
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
    $___stdout_accum = [].taint
    def ___puts(*args)
      $___stdout_accum.push args
    end
    eval($___PREFIX + ___user_code + $___SUFFIX)
  ensure
    set_trace_func nil
  end

  ___all = {
    'code' => ___user_code + "\n''",
    'trace' => $___traces,
  }
  ___all
end

def get_trace_for(___user_code)
  $___accum_stdout = ""
  $___user_code_num_lines = ___user_code.split("\n").size
  Thread.start {
    ___get_trace_for_internal(___user_code)
  }.value
end

if $0 == "get_trace_for.rb"
  pp get_trace_for("
b = lambda { |x|
  x + 3
}
puts b.call(5)
")
end
