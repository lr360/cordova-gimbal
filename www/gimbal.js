module.exports = {
    deviceready: function () {
        cordova.exec(null, null,"CBGimbal", "deviceready", []);
    }
};
