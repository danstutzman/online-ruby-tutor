// Overwrite assert so we get a stack trace not just a message
function assert(cond) {
  if (!cond) {
    throw new Error('Assertion Failure');
  }
}

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
        } else if (labelText === "function") {
          labelNode.nodeValue = "Proc";
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

    if (typeof traces_json !== "undefined") {
      var traces = $.parseJSON(traces_json);
      var setupVisualizer = function(i) {
        var visualizer = null;
        var redrawAllVisualizerArrows = function() {
          // Take advantage of the callback to convert some Python things to Ruby
          changePythonToRuby();

          if (visualizer) {
            visualizer.redrawConnectors();
          }
        };
        var visualizer = new ExecutionVisualizer(
          'trace_render_div' + i, traces[i], {
            embeddedMode: false,
            heightChangeCallback: redrawAllVisualizerArrows,
            editCodeBaseURL: null
          });
      };
      for (var i = 0; i < traces.length; i++) {
        setupVisualizer(i);
        $('#trace_render_div' + i).show();
      }

      $('#jmpStepFwd' ).click(function(event) { changePythonToRuby(); });
      $('#jmpStepBack').click(function(event) { changePythonToRuby(); });

      $('#user_code_div').hide();

      $('#edit-button').click(function(event) {
        $('.trace_render_div').hide();
        $('#user_code_div').show();
        userCodeCodeMirror.focus();
        event.preventDefault();
      });

      $('.trace_render_div').hide();
      $('#traces-table tr').click(function(e) {
        var tr = $(e.target).closest('tr');
        var traceNum = tr.attr('data-trace-num');
        if (traceNum) {
          $('.trace_render_div').hide();
          $('#trace_render_div' + traceNum).show();
          $('#trace_render_div' + traceNum + ' #jmpLastInstr').trigger('click');
          $('#traces-table tr').removeClass('selectedRow');
          tr.addClass('selectedRow');
        }
      });
      $('#traces-table tr[data-trace-num="0"]').trigger('click');

      if ($('#traces-table').length == 0) {
        $('#trace_render_div0').show();
      }
    }
  });
})();
