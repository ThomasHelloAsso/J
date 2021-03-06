window.SignupView = Backbone.View.extend({
  
  elAlert: $('#main-middle-signup-alert'),

  initialize: function(options){
    this.el = options.elMiddleSignup;
    this.elForm = options.elMiddleSignupForm;
    this.alertView = new AlertView;
    this.holderAlertView = new HolderView;

    this.validates();
    return this;
  },

  validates: function(){
    var _this = this;

    $(this.elForm).validate({
      rules: {
        'registration[username]': {
          required: true,
          username: true,
          minlength: 5
        },
        'registration[realname]': {
          required: true
        },
        'registration[email]': {
          required: true,
          email: true
        },
        'registration[password]': {
          required: true,
          minlength: 6
        }
      },
      messages: {},
      errorPlacement: function(error, element){
        var $alert_section = element.parents('tr').children('.main-registration-form-field-alert');

        $alert_section.children('.error').html(error).removeClass('hidden');
        $alert_section.children('.default_text').addClass('hidden');
      },
      success: function(label){
        var $alert_section = label.parents('.main-registration-form-field-alert');

        $alert_section.children('.error').addClass('hidden');
        $alert_section.children('.default_text').removeClass('hidden');
      },
      highlight: function(element, errorClass, validClass){
        var $el = $(element);
        $el.addClass(errorClass).removeClass(validClass);

        var $alert_section = $el.parents('tr').children('.main-registration-form-field-alert');

        $alert_section.children('.error').removeClass('hidden');
        $alert_section.children('.default_text').addClass('hidden');
      },
      unhighlight: function(element, errorClass, validClass){
        var $el = $(element);
        $el.removeClass(errorClass).addClass(validClass);

        var $alert_section = $el.parents('tr').children('.main-registration-form-field-alert');

        $alert_section.children('.error').addClass('hidden');
        $alert_section.children('.default_text').removeClass('hidden');
      },

      submitHandler: function(form){
        $(form).ajaxSubmit({
          error: function(jqXHR, textStatus, errorThrown){
            alert(textStatus);
          },
          success: function(data, textStatus, jqXHR){
            if(data.failed === true){
              _this.alertView.remove();

              _this.holderAlertView.setElement(_this.elAlert);
              _this.holderAlertView.render({className: 'holder-view-alert'});

              _this.alertView.setElement(_this.holderAlertView.holder_el);
              _this.alertView.render({error: data.error, errors: data.errors});

              if(window.Recaptcha == 'undefined'){
                alert('Recaptcha is undefined');
              }
              else{
                Recaptcha.reload();
              }
              
            }
            else{
              _this.alertView.remove();
              Recaptcha.reload();
              var aaaa = new AppAfterLogin;
              localStorage.user_session = JSON.stringify(data.content);
            }
          }
        });

        return false;
      }
    });
  },

  alertHolder: function(){
    
  }
})