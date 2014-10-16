'use strict';
(function() {
  $(document).ready(function() {
    $('*[rel="subdomain"]:not(a)').text('.' + window.location.host);
    $('a[rel="subdomain"]').attr('href', '//meta.' + window.location.host);
    $('#subdomain').bind('input change', function() {
      var invalid = !this.value.match(/^[a-z](?:[a-z-0-9]*[a-z0-9])?$/i) || this.value == 'meta';
      $('#subdomainFeedback')
        .toggleClass('has-success', !invalid)
        .toggleClass('has-error', invalid);
      $('#upload').trigger('change');
    });
    $('#spec').bind('change', function() {
      var error = $('#spec')[0].files[0] === undefined;
      var warn = !error && !$('#spec')[0].files[0].name.match(/\.ya?ml$/);
      $('#specFeedback')
        .toggleClass('has-success', !error)
        .toggleClass('has-warning', !error && warn)
        .toggleClass('has-error', error);
      $('#specFeedback .form-control-feedback')
        .toggleClass('glyphicon-ok', !error && !warn)
        .toggleClass('glyphicon-warning-sign', !error && warn)
        .toggleClass('glyphicon-remove', error);
      $('#specFeedback .warning').toggle(warn);
      $('#specFeedback .error').toggle(error);
      $('#upload').trigger('change');
    });
    $('#upload').bind('change', function() {
      var formGood = $('#upload .form-group.has-feedback.has-success').length == 2;
      $('#submit')
        .toggleClass('btn-success', formGood)
        .toggleClass('btn-default', !formGood)
        .toggleClass('disabled', !formGood);
    });;
    $('#upload').bind('submit', function(e) {
      e.preventDefault();
      console.log('action', $('#upload').attr('action'))
      $.ajax({
        url: $('#upload').attr('action'),
        type: $('#upload').attr('method'),
        success: function(data) {
          $('#uploadFailResult').hide();
          $('#uploadSuccessResult a').attr('href', data.stubUrl).text(data.stubUrl);
          $('#uploadSuccessResult .hash').text(data.hash);
          $('#uploadSuccessResult').show();
        },
        error: function(data) {
          $('#uploadSuccessResult').hide();
          $('#uploadFailResult').show()
            .find('.reason').text(data.responseJSON.message);
          $('#subdomain').trigger('input');
          $('#spec').trigger('change');
        },
        data: (new FormData($('#upload')[0])),
        cache: false,
        contentType: false,
        processData: false
      });
      return false;
    });
  });
})();