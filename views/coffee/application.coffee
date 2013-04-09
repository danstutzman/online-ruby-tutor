# Overwrite assert so we get a stack trace not just a message
window.assert = (cond) ->
  if not cond
    throw new Error('Assertion Failure')

changePythonToRuby = ->
  
  # Change None to nil
  $('span.nullObj').html 'nil'
  
  # Change True to true and False to false
  $('span.boolObj').css 'text-transform', 'lowercase'
  
  # Change dict to Hash and list to Array
  $('div.typeLabel').each (i) ->
    label = this
    labelNode = label.childNodes[0]
    if labelNode
      labelNode.nodeValue = switch labelNode.nodeValue
        when 'dict' then 'Hash'
        when 'list' then 'Array'
        when 'function' then 'Proc'
        else labelNode.nodeValue
  
  # Change 'a b' to a(newline)b
  $('span.stringObj').each (i) ->
    s = this
    sNode = s.childNodes[0]
    if sNode
      sNode.nodeValue = sNode.nodeValue.replace(/^"([\s\S]*)"$/, '$1')
      s.innerHTML = sNode.nodeValue.replace(/\\'/g, '\'')
      s.innerHTML = sNode.nodeValue.replace(/\n/g, '<br>')

  $('#pyCodeOutput').click ->
    $('#trace_render_div').hide()
    $('#user_code_div').show()

max_method_index = 0
handleFilterBySubstringKeydown = (event) ->
  text = document.getElementById('filter_by_substring').value
  method_indexes_to_show = {}
  if text is ''
    i = 0
    while i < max_method_index
      method_indexes_to_show[i] = true
      i++
  else
    for word of word_to_method_indexes
      if word.indexOf(text) is 0
        for i of word_to_method_indexes[word]
          i2 = word_to_method_indexes[word][i]
          method_indexes_to_show[i2] = true

  i = 0
  while i < max_method_index
    tr = document.getElementById("method_#{i}")
    show_or_not = method_indexes_to_show[i]
    tr.style.display = (if (show_or_not) then 'table-row' else 'none')
    i++

$(document).ready ->
  
  textarea = $('#user_code_textarea')[0]
  CodeMirror.fromTextArea(textarea,
    mode: 'ruby'
    lineNumbers: true
    tabSize: 2
    indentUnit: 2
    extraKeys: # convert tab into two spaces:
      Tab: (cm) ->
        cm.replaceSelection '  ', 'end'
    autofocus: true
  )

  if typeof traces_json isnt 'undefined'
    traces = $.parseJSON(traces_json)
    setupVisualizer = (i) ->
      visualizer = null
      redrawAllVisualizerArrows = ->
        # Take advantage of the callback to convert some Python things to Ruby
        changePythonToRuby()
        visualizer.redrawConnectors() if visualizer

      visualizer = new ExecutionVisualizer("trace_render_div#{i}", traces[i],
        embeddedMode: false
        heightChangeCallback: redrawAllVisualizerArrows
        editCodeBaseURL: null
      )

    i = 0
    while i < traces.length
      setupVisualizer i
      i++

    $('#jmpStepFwd').click (event) ->
      changePythonToRuby()

    $('#jmpStepBack').click (event) ->
      changePythonToRuby()

  for word of word_to_method_indexes
    for i of word_to_method_indexes[word]
      i2 = word_to_method_indexes[word][i]
      if i2 > max_method_index
        max_method_index = i2
  document.getElementById('filter_by_substring').addEventListener 'keydown', (e) ->
    window.setTimeout (-> handleFilterBySubstringKeydown e), 1

  $('#edit-tab').addClass 'selected'
  $('.case-content').hide()
  $('#edit-tab-link').click (event) ->
    if event.target.nodeName is 'BUTTON'
      true
    else
      $('.case-content').hide()
      $('#edit-content').show()
      $('.case-tab').removeClass 'selected'
      $('#edit-tab').addClass 'selected'
      event.preventDefault()
      false

  $('.case-tab-link').click (event) ->
    case_tab = $(event.target).closest('.case-tab')
    case_num = case_tab.attr('data-case-num')
    $('#edit-content').hide()
    $('.case-content').hide()
    $(".case-content[data-case-num='#{case_num}']").show()
    $('#edit-tab').removeClass 'selected'
    $('.case-tab').removeClass 'selected'
    case_tab.addClass 'selected'
    event.preventDefault()
    false
