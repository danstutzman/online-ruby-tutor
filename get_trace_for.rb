require 'json'
require 'pp'

$___default_global_variables = [
  :$;, :$-F, :$@, :$!, :$SAFE, :$~, :$&, :$`, :$', :$+, :$=, :$KCODE, :$-K, :$,, :$/, :$-0, :$\, :$_, :$stdin, :$stdout, :$stderr, :$>, :$<, :$., :$FILENAME, :$-i, :$*, :$?, :$$, :$:, :$-I, :$LOAD_PATH, :$", :$LOADED_FEATURES, :$VERBOSE, :$-v, :$-w, :$-W, :$DEBUG, :$-d, :$0, :$PROGRAM_NAME, :$-p, :$-l, :$-a, :$binding, :$1, :$2, :$3, :$4, :$5, :$6, :$7, :$8, :$9,

 :$fileutils_rb_have_lchmod,
 :$fileutils_rb_have_lchown,
 :$CODERAY_DEBUG,
 :$rdebug_state,
 :$__dbg_interface,
 :$rdebug_in_irb,
 :$CGI_ENV,
]
$___global_variables_from_previous_execution = []

def pay_attention_to(___new_global)
  proc { |_ignored|
      $___global_variables_from_previous_execution.delete(___new_global)
  }
end

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
            ["FUNCTION", "line #{value.source_location[1]}", nil]
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

    if $___first_line
      for ___new_global in (global_variables -
          $___global_variables_from_previous_execution -
          $___default_global_variables)
        $___global_variables_from_previous_execution.push(___new_global)
        if !___new_global.to_s.start_with?('$___')
          trace_var ___new_global, pay_attention_to(___new_global)
        end
      end
      $___first_line = false
    end

    globals = binding.eval('global_variables')
    global_values = {}
    globals.reject! { |global|
      global.to_s.start_with?('$___') ||
      $___global_variables_from_previous_execution.include?(global) ||
      $___default_global_variables.include?(global)
    }
    globals.each do |global_name|
      value = binding.eval(global_name.to_s)
      global_values[global_name.to_s] = represent_value(value, heap)
    end

    if $___stack_to_render.last
      $___stack_to_render.last['encoded_locals'] = local_values.clone
      $___stack_to_render.last['ordered_varnames'] = locals.clone
      $___stack_to_render.last['is_highlighted'] = (event == 'call')
      $___stack_to_render.last['unique_hash'] = id.to_s
    end
  
    trace = {
      'ordered_globals' => globals,
      'stdout' => $stdout.string.clone,
      'func_name' => 'main',
      'stack_to_render' => $___stack_to_render.map { |frame| frame.clone },
      'globals' => global_values,
      'heap' => heap,
      'line' => line,
      'event' => 'step_line',
    }
    $___traces.push trace
  end
}

def capture_stdout
  $stdout = StringIO.new
  yield
  return $stdout.string.clone
ensure
  $stdout = STDOUT
end

def get_trace_for(___user_code)
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

  ___globals_before = global_variables
  for ___old_global in $___global_variables_from_previous_execution
    if !___old_global.to_s.start_with?('$___')
      trace_var ___old_global, pay_attention_to(___old_global)
    end
  end

  begin
    $___first_line = true
    set_trace_func $___trace_func
    capture_stdout do
      eval(___user_code + "\n''")
    end
  ensure
    set_trace_func nil
  end

  for ___old_global in $___global_variables_from_previous_execution
    untrace_var ___old_global
  end
  $___global_variables_from_previous_execution +=
    global_variables - ___globals_before

  ___all = {
    'code' => ___user_code + "\n''",
    'trace' => $___traces,
  }
  JSON.dump(___all)
end
