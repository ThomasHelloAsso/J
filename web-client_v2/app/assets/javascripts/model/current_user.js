window.CurrentUserModel = Backbone.Model.extend({

  setAuth: function(){
    var _this = this;

    $(window).bind('jotky_login', function(event, token){
      _this.setProfile(token, true);
    });

    $(window).bind('jotky_logout', function(event, token){
      _this.unsetData();
      _this.unsetToken();

      _this.after_logout.call(_this, _this.data(), _this.token());
    });
  },

  data: function(){
    if(localStorage.jotky_user_session){
      data = localStorage.jotky_user_session;
    }
    else{
      data = '{}';
    }
    return JSON.parse(data);
  } ,

  token: function(){
    return $.cookie("jotky_token");
  },

  setData: function(data){
    localStorage.jotky_user_session = JSON.stringify(data);
  },

  setToken: function(token){
    $.cookie("jotky_token", token, {
      expires : 10,
      path    : '/',
      domain  : window.location.hostname,
      secure  : false
    });
  },

  unsetData: function(){
    localStorage.jotky_user_session = "{}";
  },

  unsetToken: function(){
    $.cookie("jotky_token", null)
    $.cookie("jotky_token", null, {
      path    : '/',
      domain  : window.location.hostname,
      secure  : false,
      raw: true
    });
  },

  setProfile: function(token, with_login){
    var _this = this;
    
    $.ajax({
      url: '/profiles.json',
      data: {
        token: token
      },
      error: function(jqXHR, textStatus, errorThrown){
        alert(textStatus);
      },
      success: function(data, textStatus, jqXHR){
        if(data.failed === true){
          alert(data.error)
        }
        else{

          
          _this.setData(data.content);
          _this.setToken(token);

          if(with_login){_this.setLogin();}
        }
      }
    });
  },

  setLogin: function(){
    this.after_login.call(this, this.data(), this.token());
  },

  after_login: function(){},

  after_logout: function(){}
});
