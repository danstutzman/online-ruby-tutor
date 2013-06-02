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
  
  # "a\n'b" should be rendered as a(next line)'b not "a \'b"
  $('span.stringObj').each (i) ->
    s = this
    sNode = s.childNodes[0]
    if sNode
      without_dquotes = sNode.nodeValue.replace(/^"([\s\S]*)"$/, '$1')
      sNode.nodeValue = without_dquotes.replace(/\\'/g, '\'')

  $('#pyCodeOutput').click ->
    $('#trace_render_div').hide()
    $('#user_code_div').show()

max_method_index = 0
showAllMethods = ->
  i = 0
  while i < max_method_index
    tr = $("#method_#{i}")
    tr.show()
    i++

filterMethodsByText = (old_method_indexes_to_show) ->
  textFilter = $('#filter_by_substring').val()
  if textFilter is ''
    old_method_indexes_to_show
  else
    new_method_indexes_to_show = {}
    for word of word_to_method_indexes
      if word.indexOf(textFilter) is 0
        for i of word_to_method_indexes[word]
          method_index = word_to_method_indexes[word][i]
          if old_method_indexes_to_show[method_index]
            new_method_indexes_to_show[method_index] = true
    new_method_indexes_to_show

filterMethodsByIHave = (old_method_indexes_to_show) ->
  input = $('#i-have').val()
  if input is ''
    old_method_indexes_to_show
  else
    new_method_indexes_to_show = {}
    for method_index in (i_have_to_method_indexes[input] || [])
      if old_method_indexes_to_show[method_index]
        new_method_indexes_to_show[method_index] = true
    for method_index in (i_have_to_method_indexes["#{input}s"] || [])
      if old_method_indexes_to_show[method_index]
        new_method_indexes_to_show[method_index] = true
    if input isnt 'statements' && input isnt 'file'
      for method_index in (i_have_to_method_indexes['object'] || [])
        if old_method_indexes_to_show[method_index]
          new_method_indexes_to_show[method_index] = true
    new_method_indexes_to_show

filterMethodsByINeed = (old_method_indexes_to_show) ->
  input = $('#i-need').val()
  if input is ''
    old_method_indexes_to_show
  else
    new_method_indexes_to_show = {}
    for method_index in (i_need_to_method_indexes[input] || [])
      if old_method_indexes_to_show[method_index]
        new_method_indexes_to_show[method_index] = true
    for method_index in (i_need_to_method_indexes["#{input}s"] || [])
      if old_method_indexes_to_show[method_index]
        new_method_indexes_to_show[method_index] = true
    new_method_indexes_to_show

handleFilters = (event) ->
  method_indexes_to_show = {}
  for i in [0..max_method_index]
    method_indexes_to_show[i] = true

  method_indexes_to_show = filterMethodsByText(method_indexes_to_show)
  method_indexes_to_show = filterMethodsByIHave(method_indexes_to_show)
  method_indexes_to_show = filterMethodsByINeed(method_indexes_to_show)

  for i in [0..max_method_index]
    tr = $("#method_#{i}")
    if method_indexes_to_show[i] then tr.show() else tr.hide()

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

    # Use id selectors instead of # because there are multiple buttons
    # with the same id unfortunately.
    $("button[id=jmpFirstInstr]").click (event) -> changePythonToRuby()
    $("button[id=jmpStepBack]").click (event)   -> changePythonToRuby()
    $("button[id=jmpStepFwd]").click (event)    -> changePythonToRuby()
    $("button[id=jmpLastInstr]").click (event)  -> changePythonToRuby()

  for word of word_to_method_indexes
    for i of word_to_method_indexes[word]
      i2 = word_to_method_indexes[word][i]
      if i2 > max_method_index
        max_method_index = i2

  $('#filter_by_substring').keydown (e) ->
    window.setTimeout (-> handleFilters e), 1
  $('#i-have').change (e) ->
    handleFilters(e)
  $('#i-need').change (e) ->
    handleFilters(e)

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

  $('#restore-button').click (event) ->
    confirm('Are you sure you want to discard your current code?')
