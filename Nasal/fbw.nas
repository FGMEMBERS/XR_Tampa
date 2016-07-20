#########################################
## Designed by Omega, Hooray & Redneck ##
#########################################

# CONSTANTS

var RAD2DEG = 57.2957795;
var DEG2RAD = 0.0174532925;
var INCREMENT = 0.001;

# helpers:

##
# a wrapper to determine if a value is within a certain range
# usage:in_range(1,[min,max] );
# e.g.: in_range(1, [-1,+1] );
#
var in_range = func(value, range) {
 var min=range[0];
 var max=range[1];
 return ((value <= min) and (value >= max));
}

var fbw = {
	init : func { 
        me.UPDATE_INTERVAL = INCREMENT; 
        me.loopid = 0; 
		me.throttle = 0;
		me.throttlefix = 0;
		me.throttleinit = 0;
		me.targetthrottle = 0;
		me.turnthrottlefix = 0;
		me.targetaileron = 0;
		me.targetelevator = 0;
		me.targetrudder = 0;
		me.adjustelevators = 0;
		me.stabilize = 0;

		me.stabpitch = 0;
		me.stabroll = 0;

		me.disconnectannounce = 0;
		# use a vector of throttles, this can be later on used to support more than
		# just two engines
		me.throttles = [nil,nil]; 


## Initialize with FBW Activated

setprop("/controls/fbw/active", 1);
setprop("/controls/fbw/rudder", 1);
setprop("/controls/fbw/yaw-damper", 1);
setprop("/controls/fbw/bank-limit", 35);

## Initialize Control Surfaces

setprop("/fdm/jsbsim/fcs/aileron-fbw-output", 0);
setprop("/fdm/jsbsim/fcs/rudder-fbw-output", 0);
setprop("/fdm/jsbsim/fcs/elevator-fbw-output", 0);

        me.reset(); 
}, 
	update : func {

var fcs = "/fdm/jsbsim/fcs/";

## Fix Damp Rate according to Framerate

me.fpsfix = 1;
if (getprop("/sim/frame-rate") != nil) me.fpsfix = 25 / getprop("/sim/frame-rate");

## Bank Limit Setting

me.banklimit = getprop("/controls/fbw/bank-limit");

## Position and Orientation

me.altitudeagl = getprop("/position/altitude-agl-ft");

var altitudemsl = getprop("/position/altitude-ft");

var pitch = getprop("/orientation/pitch-deg");
me.roll = getprop("/orientation/roll-deg");

var airspeedkt = getprop("/velocities/airspeed-kt");

## Flight Control System Properties

var elevtrim = getprop("/controls/flight/elevator-trim");
var ailtrim = getprop("/controls/flight/aileron-trim");

me.aileronin = getprop(fcs~"aileron-cmd-norm");
me.elevatorin =  getprop(fcs~"elevator-cmd-norm");
me.rudderin = getprop(fcs~"rudder-cmd-norm");

## FBW Output (actual surface positions)

me.aileronout = getprop(fcs~"aileron-fbw-output");
me.elevatorout =  getprop(fcs~"elevator-fbw-output");
me.rudderout = getprop(fcs~"rudder-fbw-output");

## Engine Throttle Positions

var engines = props.globals.getNode("controls/engines").getChildren("engine");
forindex(var index; engines ) {
me.throttles[index] = engines.getNode("engine",index).getNode("throttle").getValue() );
}

me.throttles[0] = getprop("[0]/throttle");
me.throttles[1] = getprop("controls/engines/engine[1]/throttle");


## This is where the FBW actually does its job ;)

me.check_if_active();

if (getprop("/controls/fbw/active")) {

me.disconnectannounce = 0;

me.update_ailerons();
me.update_elevator();

## ALPHA PROTECTION

if (pitch > 20) {
setprop("/controls/fbw/alpha-protect", 1);
setprop("/controls/fbw/alpha-limit", 22);
} elsif (pitch < -20) {
setprop("/controls/fbw/alpha-protect", 1);
setprop("/controls/fbw/alpha-limit", -22);
} else setprop("/controls/fbw/alpha-protect", 0);

## PROTECTION END TRIM FIX

if ((getprop("/controls/fbw/alpha-limit") == 0) and (getprop("/controls/fbw/autostable") == 0) and (getprop("/autopilot/locks/altitude") == "")) {
if (getprop("/controls/flight/elevator-trim") < 0) setprop("/controls/flight/elevator-trim", getprop("/controls/flight/elevator-trim") + 0.03);
if (getprop("/controls/flight/elevator-trim") > 0) setprop("/controls/flight/elevator-trim", getprop("/controls/flight/elevator-trim") - 0.03);
}

## AUTO-STABILIZATION

### Get the aircraft to maintain pitch and roll when stick is at the center

if ( in_range(me.elevatorin, [-0.1,0.1]) and in_range(me.aileronin, [-0.1,0.1]) ) {

if (me.stabilize == 0) {
setprop("/controls/fbw/stabpitch-deg", pitch);
setprop("/controls/fbw/stabroll-deg", me.roll);
me.stabilize = 1;
}

if ((airspeedkt >= 220) and (me.altitudeagl >= 3500)) {
setprop("/controls/fbw/autostable", 1);
} else {
setprop("/controls/fbw/autostable", 0);
}

} else {
me.stabilize = 0;
setprop("/controls/fbw/autostable", 0);
}
## THROTTLE CONTROLS

### Disconnect Throttle fix if manually overridden

if (me.throttles[0] != me.throttle) {
me.throttlefix = 0;
me.turnthrottlefix = 0;
}


### Adjust throttle while turning

if ((me.roll <= -5) or (me.roll >= 5)) {

if (me.turnthrottlefix == 0) {
me.throttleinit = me.throttles[0];
me.turnthrottlefix = 1;
}

me.targetthrottle = me.throttleinit + (me.throttleinit * math.sin(math.abs(me.roll * DEG2RAD)))/2;

if (me.targetthrottle > me.throttles[0]) {
me.inc_throttles();
} elsif (me.targetthrottle < me.throttles[0]) {
me.dec_throttles();} 

}

if ( in_range(me.roll,[-5,5]) and (me.turnthrottlefix == 1) ) {


if (me.throttles[0] <= me.throttleinit - 0.05) {
me.inc_throttles();
} elsif (me.throttles[0] > me.throttleinit + 0.05) {
me.dec_throttles();
} else me.turnthrottlefix = 0;
}

### Reduce throttle if aircraft is faster than 250 KIAS under 10000 ft

if ((airspeedkt >= 250) and (altitudemsl <= 10000) and me.throttles_not_idle() ) {
me.dec_throttles();
me.throttlefix = 1;
}

if ((me.throttlefix == 1) and (airspeedkt < 245) and (altitudemsl <= 10000) and me.throttles_not_maxed() ) {
me.inc_throttles();
}

### Adjust Throttle to stay under Vne

if ((airspeedkt >= 350) and (altitudemsl > 10000) and me.throttles_not_idle() ) {
me.dec_throttles();
me.throttlefix = 1;
}

if ((me.throttlefix == 1) and (airspeedkt < 340) and (altitudemsl > 10000) and me.throttles_not_maxed() ) {
me.inc_throttles();
}

### Adjust Throttle to keep from stalling

if ((airspeedkt < 125) and (me.altitudeagl > 250) and me.throttles_not_maxed() ) {
me.inc_throttles();

### Also help by pushing forward on the stick

me.elevatorout += 0.02;

}

## RUDDER CONTROLS

if (getprop("/controls/fbw/rudder")) {

if ((me.roll < -5) or (me.roll > 5)) {
me.targetrudder = me.aileronout / 2;

if (me.targetrudder < me.rudderout) me.rudderout -= 0.015;
if (me.targetrudder > me.rudderout) me.rudderout += 0.015;

} }

me.update_yaw_damper();

# Transmit output signals to surfaces

setprop(fcs~"aileron-fbw-output", me.aileronout);
setprop(fcs~"elevator-fbw-output", me.elevatorout);
setprop(fcs~"rudder-fbw-output", me.rudderout);

setprop("controls/engines/engine[0]/throttle", me.throttles[0]);
setprop("controls/engines/engine[1]/throttle", me.throttles[1]);

me.throttle = me.throttles[0]; # This is to find out if the pilot moved the throttle

} else {

# Transmit input signals directly to surfaces

setprop(fcs~"aileron-fbw-output", me.aileronin);
setprop(fcs~"elevator-fbw-output", me.elevatorin);
setprop(fcs~"rudder-fbw-output", me.rudderin);

}

},
    update_elevator: func {
    ## ELEVATOR CONTROLS
    if (me.elevatorin > me.elevatorout) me.elevatorout += 0.05 * me.fpsfix;
    if (me.elevatorin < me.elevatorout) me.elevatorout -= 0.05 * me.fpsfix;
    if ((me.elevatorin - me.elevatorout < 0.05) and (me.elevatorin - me.elevatorout > 0)) me.elevatorout += 0.01; 
    if ((me.elevatorout - me.elevatorin < 0.05) and (me.elevatorin - me.elevatorout < 0)) me.elevatorout -= 0.01; 
},

    update_yaw_damper: func {
    ## YAW DAMPER

    if (getprop("/controls/fbw/yaw-damper")) {

    if (me.rudderin > me.rudderout) me.rudderout += 0.05 * me.fpsfix;

    if (me.rudderin < me.rudderout) me.rudderout -= 0.05 * me.fpsfix;

    } else {

    me.rudderout = me.rudderin;

    }

},
    update_ailerons: func {
      ## AILERON CONTROLS

      ### Set Aileron Direction and Roll Direction

      me.rolldir = 0;
      if (me.roll < 0) me.rolldir = -1;
      if (me.roll > 0) me.rolldir = 1;


      me.ailerondir = 0;
      if (me.aileronin < 0) me.ailerondir = -1;
      if (me.aileronin > 0) me.ailerondir = 1;


      if ( in_range(me.roll,[-me.banklimit,me.banklimit]) or (me.rolldir != me.ailerondir)) {


      if (me.aileronin > me.aileronout) me.aileronout += 0.05 * me.fpsfix;

      if (me.aileronin < me.aileronout) me.aileronout -= 0.05 * me.fpsfix;

      } else {

      ### Don't let the plane bank past the bank limit

      if (me.roll < -me.banklimit) me.targetaileron = -(me.roll + me.banklimit) * 0.025;
      if (me.roll > me.banklimit) me.targetaileron = -(me.roll - me.banklimit) * 0.025;

      if (me.aileronout < me.targetaileron) me.aileronout += 0.025 * me.fpsfix;
      if (me.aileronout > me.targetaileron) me.aileronout -= 0.025 * me.fpsfix;

      }

},
    check_if_active : func {
	### The Fly-by--wire only works when it is active. In the Boeing 787, pilots have the option to disable fly-by-wire and use power-by-wire* in case of emergencies. The Fly By Wire Configuration includes: On/Off, Bank Limit and Rudder Control. The FBW Configs can be set in the FBW CONFIG Page in the CDU(s)

	## Turn on Fly By Wire only if we have power

	if (getprop("/systems/electrical/outputs/efis") != nil) {
	  if ((getprop("/systems/electrical/outputs/efis") < 9) and (me.altitudeagl >= 200)) {
	  setprop("/controls/fbw/active", 0);
	  if (me.disconnectannounce == 0) {
	    screen.log.write("Fly By Wire Disconnected!", 1, 0, 0);
	    me.disconnectannounce = 1;
	  }
	}
	}
},

	inc_throttles: func {
	forindex(var t; me.throttles)
	  me.throttles[t] += INCREMENT * me.fpsfix;
},

	dec_throttles:func {
	forindex(var t; me.throttles)
	  me.throttles[t] -= INCREMENT * me.fpsfix;
},
	throttles_not_idle: func {
	  foreach(var t; me.throttles) {
	      if (me.throttles[t] == 0) return 0; # at least one throttle is idle
	    }
	return 1; # throttles are idle
},
	throttles_not_maxed: func {
	  foreach(var t; me.throttles) {
	      if (me.throttles[t] == 1) return 0; # at least one throttle is maxed
	    }
	return 1; # throttles are not maxed
},
    reset : func {
        me.loopid += 1;
        me._loop_(me.loopid);
    },
    _loop_ : func(id) {
        id == me.loopid or return;
        me.update();
        settimer(func { me._loop_(id); }, me.UPDATE_INTERVAL);
    }

};

fbw.init();
print("Fly-By-Wire ......... Initialized");