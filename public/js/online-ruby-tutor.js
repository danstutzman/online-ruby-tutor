(function() {
  var userCodeCodeMirror = null;

  var changePythonToRuby = function() {
    // Change None to nil
    $('span.nullObj').html('nil');

    // Change True to true and False to false
    $('span.boolObj').css('text-transform', 'lowercase');

    // Change dict to Hash and list to Array
    $('div.typeLabel').each(function(i) {
      var label = this;
      var labelNode = label.childNodes[0];
      if (labelNode) {
        var labelText = labelNode.nodeValue;
        if (labelText === "dict") {
          labelNode.nodeValue = "Hash";
        } else if (labelText === "list") {
          labelNode.nodeValue = "Array";
        }
      }
    });

    $('#pyCodeOutput').click(function() {
      $('#trace_render_div').hide();
      $('#user_code_div').show();
    });
  }

  $(document).ready(function() {
    var textarea = $('#user_code_textarea')[0];
    userCodeCodeMirror = CodeMirror.fromTextArea(textarea, {
      mode: 'ruby',
      lineNumbers: true,
      tabSize: 2,
      indentUnit: 2,
      // convert tab into two spaces:
      extraKeys: {Tab: function(cm) {cm.replaceSelection("  ", "end");}},
      autofocus: true
    });

    if (typeof trace_json !== "undefined") {
      var trace = $.parseJSON(trace_json);
      var visualizer = null;
      var redrawAllVisualizerArrows = function() {
        // Take advantage of the callback to convert some Python things to Ruby
        changePythonToRuby();

        if (visualizer) {
          visualizer.redrawConnectors();
        }
      };
      var visualizer = new ExecutionVisualizer('trace_render_div', trace, {
        embeddedMode: true,
        heightChangeCallback: redrawAllVisualizerArrows,
        editCodeBaseURL: null
      });

      $('#jmpStepFwd' ).click(function(event) { changePythonToRuby(); });
      $('#jmpStepBack').click(function(event) { changePythonToRuby(); });

      $('#user_code_div').hide();

      $('#trace_render_div_cover').show();
      $('#trace_render_div_cover').click(function(event) {
        $('#trace_render_div_cover').hide();
        $('#trace_render_div').hide();
        $('#user_code_div').show();
        userCodeCodeMirror.focus();
      });
    }

    $('#submit_code').removeAttr('disabled');
  });
})();
