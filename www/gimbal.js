module.exports = {
  startService: function (appid, appsecret, callbackurl, success, failed) {
    exec(success, failed, 'CBGimbal', 'startService', [appid, appsecret, callbackurl]);
  }
};
