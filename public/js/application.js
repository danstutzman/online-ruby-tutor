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

    // Change "a b" to a(newline)b
    $('span.stringObj').each(function(i) {
      var s = this;
      var sNode = s.childNodes[0];
      if (sNode) {
        sNode.nodeValue = sNode.nodeValue.replace(/^"([\s\S]*)"$/, "$1");
        s.innerHTML = sNode.nodeValue.replace(/\\"/g, "\"");
        s.innerHTML = sNode.nodeValue.replace(/\n/g, "<br>");
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
      }

      $('#jmpStepFwd' ).click(function(event) { changePythonToRuby(); });
      $('#jmpStepBack').click(function(event) { changePythonToRuby(); });

    } // end if traces_json defined

    var max_method_index = 0;
    for (var word in word_to_method_indexes) {
      for (i in word_to_method_indexes[word]) {
        var i2 = word_to_method_indexes[word][i];
        if (i2 > max_method_index) {
          max_method_index = i2;
        }
      }
    }

    function handleFilterBySubstringKeydown(event) {
      var text = document.getElementById('filter_by_substring').value;
      var method_indexes_to_show = {};
      if (text == '') {
        for (var i = 0; i < max_method_index; i++) {
          method_indexes_to_show[i] = true;
        }
      } else {
        for (var word in word_to_method_indexes) {
          if (word.indexOf(text) == 0) {
            for (i in word_to_method_indexes[word]) {
              var i2 = word_to_method_indexes[word][i];
              method_indexes_to_show[i2] = true;
            }
          }
        }
      }

      for (var i = 0; i < max_method_index; i++) {
        var tr = document.getElementById('method_' + i);
        var show_or_not = method_indexes_to_show[i];
        tr.style.display = (show_or_not) ? 'table-row' : 'none';
      }
    }
    document.getElementById('filter_by_substring').addEventListener(
      'keydown', function(e) {
        window.setTimeout(function() { handleFilterBySubstringKeydown(e) }, 1);
      }
   );

   $('#edit-tab').addClass('selected');
   $('.case-content').hide();

   $('#edit-tab-link').click(function(event) {
     if (event.target.nodeName == 'BUTTON') {
       return true;
     } else {
       $('.case-content').hide();
       $('#edit-content').show();

       $('.case-tab').removeClass('selected');
       $('#edit-tab').addClass('selected');

       event.preventDefault();
       return false;
     }
   });

   $('.case-tab-link').click(function(event) {
     var case_tab = $(event.target).closest('.case-tab');
     var case_num = case_tab.attr('data-case-num');

     $('#edit-content').hide();
     $('.case-content').hide();
     $('#trace_render_div' + case_num).show();

     $('#edit-tab').removeClass('selected');
     $('.case-tab').removeClass('selected');
     case_tab.addClass('selected');

     event.preventDefault();
     return false;
   });

  }); // end ready
})(); // end immediate function
