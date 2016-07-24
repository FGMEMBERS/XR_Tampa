var RPM_arm=props.globals.getNode("/instrumentation/alerts/rpm",1);
var last_time = 0;
var start_timer=0;
var GPS = 0.002222;  ### avg cruise = 8 gph
var Fuel_Density=6.0;
var Fuel1_Level= props.globals.getNode("/consumables/fuel/tank/level-gal_us",1);
var Fuel1_LBS= props.globals.getNode("/consumables/fuel/tank/level-lbs",1);
var Fuel2_Level= props.globals.getNode("/consumables/fuel/tank[1]/level-gal_us",1);
var Fuel2_LBS= props.globals.getNode("/consumables/fuel/tank[1]/level-lbs",1);
var TotalFuelG=props.globals.getNode("/consumables/fuel/total-fuel-gals",1);
var TotalFuelP=props.globals.getNode("/consumables/fuel/total-fuel-lbs",1);
var NoFuel=props.globals.getNode("/engines/engine/out-of-fuel",1);

var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10);
FHmeter.stop();



setlistener("/sim/signals/reinit", func {
    RPM_arm.setBoolValue(0);
    setprop("/controls/engines/engine/throttle",1);
});

setlistener("/sim/current-view/view-number", func(vw) {
    var nm = vw.getValue();
    setprop("sim/model/sound/volume", 1.0);
    if(nm == 0 or nm == 7)setprop("sim/model/sound/volume", 0.5);
},1,0);

setlistener("/gear/gear[1]/wow", func(gr) {
    if(gr.getBoolValue()){
    FHmeter.stop();
    }else{FHmeter.start();}
},0,0);

setlistener("/engines/engine/out-of-fuel", func(fl) {
    var nofuel = fl.getBoolValue();
    if(nofuel)kill_engine();
},0,0);

setlistener("/controls/electric/key", func(key){
    var key = key.getValue();
    if(key == 0)kill_engine();
},0,0);

setlistener("controls/engines/engine[0]/clutch", func(clutch){
    var clutch= clutch.getBoolValue();
    if(clutch and props.globals.getNode("/engines/engine/running",1).getBoolValue()){
      setprop("/engines/engine/clutch-engaged",1);
    }else{
      setprop("/engines/engine/clutch-engaged",0);
    }
},0,0);

##############################################
######### AUTOSTART / AUTOSHUTDOWN ###########
##############################################

setlistener("/sim/model/start-idling", func(idle){
    var run= idle.getBoolValue();
    if(run){
    Startup();
    }else{
    Shutdown();
    }
},0,0);

var Startup = func {
  setprop("/controls/electric/battery-switch",1);
  setprop("/controls/electric/engine/generator",1);
  setprop("/controls/electric/key",4);
  setprop("/engines/engine/rpm",2700);
  setprop("/engines/engine/running",1);
  setprop("/controls/engines/engine/clutch",1);
}

var Shutdown = func {
  setprop("/controls/electric/battery-switch",0);
  setprop("/controls/electric/engine/generator",0);
  setprop("/controls/electric/key",0);
  setprop("/engines/engine/rpm",0);
  setprop("/engines/engine/running",0);
  setprop("/controls/engines/engine/clutch",0);
}

###############################################
###############################################
###############################################

var update_system = func{
  settimer(update_system, 0);
}