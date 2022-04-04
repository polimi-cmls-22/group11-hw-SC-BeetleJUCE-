(
//---------------------------------------------------VARIABLES DEFINITIONS------------------------------------------------
//VAR WINDOWS
var w_main, comp, edit_window, w_gliss;
//VAR ELEMENTS (buttons, other GUI elements...)
var play, stop, reset, edit, edit_env, randomize, randomizeAuto, wave, gliss, env_curve, on, num, type, reset_env;
//VAR VARIABLES
var f0=440, n=10, active=n;

x = Array.newClear(n); //active synths
f = Array.newClear(n); for(0, n-1, {arg i; f[i]=f0*(i+1);}); //harmonics of f0
a = Array.newClear(n); //frequencies amplitude
e = Array.newClear(n); for(0, n-1, {arg i; e[i]=Env([0, 1, 0.9, 0],[0.1, 0.5, 1], 0)}); //envelopes
c = Array.newClear(n); for(0, n-1, {arg i; c[i]=0}); //curvature of envelopes
h = Array.newClear(n); for(0, n-1, {arg i; h[i]=1}); //array of active sliders

l = Array.newClear(n); //labels
k = Array.newClear(n); //knobs (detuning)
b = Array.newClear(n); //envelope edit buttons

//Synth used for continuos sounds
SynthDef(\base,{|out, freq=440, mul|
	Out.ar(out, SinOsc.ar(freq:freq, mul:mul)!2)
}).add;
//-------------------------------------------------------------MIDI SETUP-------------------------------------------------
// MIDI Setup
MIDIClient.init;
// Connect all available MIDI Devices
MIDIIn.connectAll;
// Print all incoming MIDI messages to the console
//MIDIFunc.trace(true);

//-----------------------------------------------------------MAIN WINDOW-------------------------------------------------
//MAIN WINDOW
w_main = Window("Main", Rect(600, 50, 800, 450)).background_(Color.white);
comp = CompositeView(w_main, Rect(100, 0, w_main.bounds.width-100, w_main.bounds.height)).background_(Color.rand).resize_(5);
w_main.front.alwaysOnTop;
w_main.onClose_({CmdPeriod.run;});
//Open standard visualizers
FreqScope.new(718, 200).window.setTopLeftBounds(Rect(600,15));
Stethoscope.new.window.setTopLeftBounds(Rect(600,270,800,235));

//--------------------------------------------------------------GUI--------------------------------------------------------
for(0, n-1, {arg i;
	//amp sliders
	a[i] = Slider(comp, Rect((comp.bounds.width/n)*i, 0, comp.bounds.width/n, comp.bounds.height-180));
	a[i].knobColor_(Color.rand);
	a[i].value = 0.5;
	a[i].action_({
		if(a[i].value == 0, {h[i] = 0;}, {h[i] = 1;});
		active = h.sum;
		//active.postln;
	});

	//freq labels
	l[i] = StaticText(comp, Rect((comp.bounds.width/n)*i, comp.bounds.height-180, comp.bounds.width/n, 20));
	l[i].string = f[i];
	//freq detunes knobs
	g = ControlSpec.new(minval: -30*(i+1), maxval: 30*(i+1), default: 0);
	k[i] = EZKnob(comp, Rect((comp.bounds.width/n)*i, comp.bounds.height-160, comp.bounds.width/n, comp.bounds.height/4), controlSpec: g, initVal:0, label:"  DETUNE (Hz)");
	//env edit buttons
	b[i] = Button(comp, Rect((comp.bounds.width/n)*i, comp.bounds.height-40, 60, 30));
	b[i].string = "ENV";
	b[i].action_({ var tmp2 = e[i].times;
		// Check the correct size for visualization
		if(e[i].times.size>3, {tmp2 = tmp2.put(0, 0.0);}, {tmp2 = tmp2.insert(0, 0.0);});

		edit_window = Window("Edit envelope", Rect(700, 300, 550, 400)).background_(Color.white).onClose_({edit_window.visible_(false);}).front;

		env_curve =EZKnob(edit_window, Rect(10,10,100,100), "Curve", ControlSpec.new(minval: -10, maxval: 10, default: c[i])).action_{(
			c[i] = env_curve.value;
			edit_env.curves_(c[i]);
		)};

		reset_env = Button(edit_window, Rect(10, 150, 100, 30));
		reset_env.string = "RESET";
		reset_env.action_({
			e[i]=Env([0, 1, 0.9, 0],[0.1, 0.5, 1], 0);
			c[i] = 0;
			env_curve.value = c[i];
			edit_env.value_([tmp2, e[i].levels]).curves_(c[i]);
		});

	edit_env = EnvelopeView(edit_window, Rect(150, 0, 400, 400)).resize_(5)
	    .drawLines_(true)
		.selectionColor_(Color.red)
		.drawRects_(true)
		.resize_(5)
		.step_(0.05)
		.thumbSize_(5)
	    .action_({arg b; var tmp;
		    // Truncate current element to match Env requirements
		    tmp = b.value[0];
		    tmp.removeAt(0);
		    // Generate envs from values
		    e[i]=Env(b.value[1], tmp, c[i]);
		})
		.value_([tmp2, e[i].levels]).curves_(c[i]);

	});
});

//NOTE SPACING TYPE
type = Button(w_main, Rect(10, 230, 80, 20))
    .states_([ ["Semitone",Color.black, Color.yellow], ["Linear",Color.black, Color.yellow] ])
    .action_({
	if(type.value==1, {
		for(0, n-1, {arg i;
			f[i]=f0*pow(2, i/12);
			//f[i].postln;
			l[i].string = f[i];
		});
	},{
		for(0, n-1, {arg i;
			f[i]=f0*(i+1);
			//f[i].postln;
			l[i].string = f[i];
	    });
	});
});

//---------------------------------------------------------------BUTTONS---------------------------------------------------------
//PLAY
play = Button(w_main, Rect(10, 10, 80, 20));
play.string = "PLAY";
play.font_(Font("Arial Rounded MT Bold", 12));
play.action_({
	for(0, n-1, {arg i;
		x[i] = {SinOsc.ar(f[i]+k[i].value)!2*a[i].value/active*EnvGen.kr(e[i], doneAction:2)}.play;
		l[i].string = f[i]+k[i].value;});
});
on = MIDIFunc.noteOn({ |veloc, num, chan, src|
    num.midicps.postln;//from midi number to Hz
    f0 = num.midicps;
	//f0.postln;
	(
		AppClock.sched(0.001,{ arg time;
			//["AppClock has been playing for ",time].postln;
			if(type.value == 0, {
				type.valueAction_(0);
			}, {type.valueAction_(1);});
			play.valueAction_(0);
			f0 = num.midicps;
		});
	)
	});


//STOP
stop = Button(w_main, Rect(10, 35, 80, 20));
stop.font_(Font("Arial Rounded MT Bold", 12));
stop.string = "STOP";
stop.action_({CmdPeriod.run;
	on = MIDIFunc.noteOn({ |veloc, num, chan, src|
    num.midicps.postln;//from midi number to Hz
    f0 = num.midicps;
	//f0.postln;
	(
		AppClock.sched(0.001,{ arg time;
			//["AppClock has been playing for ",time].postln;
			if(type.value == 0, {
				type.valueAction_(0);
			}, {type.valueAction_(1);});
			play.valueAction_(0);
			f0 = num.midicps;
		});
	)
	});
});
//RESET
reset = Button(w_main, Rect(10, 60, 80, 20));
reset.string = "RESET";
reset.font_(Font("Arial Rounded MT Bold", 12));
reset.action_({
	for(0, n-1, {arg i;
		a[i].value=0;
		k[i].value=0;
		e[i]=Env([0, 1, 0.9, 0],[0.1, 0.5, 1], 0);
		c[i] = 0;});
});
//EDIT ALL ENVELOPES
edit = Button(w_main, Rect(10, comp.bounds.height-40, 80, 30));
edit.string = "EDIT ALL";
edit.action_({ var tmp2 = e[0].times;
	// Check the correct size for visualization
	if(e[0].times.size>3, {}, {tmp2 = tmp2.insert(0, 0.0);});

	edit_window = Window("Edit all envelopes", Rect(700, 300, 550, 400)).background_(Color.white).onClose_({edit_window.visible_(false);}).front;

	env_curve =EZKnob(edit_window, Rect(10,10,100,100), "Curve", ControlSpec.new(minval: -10, maxval: 10, default: c[0])).action_{(
		for(0, n-1, {arg i; c[i]=env_curve.value;});
		edit_env.curves_(c[0]);
	    )};

	reset_env = Button(edit_window, Rect(10, 150, 100, 30));
	reset_env.string = "RESET ALL";
	reset_env.action_({
		for(0, n-1, {arg i; e[i]=Env([0, 1, 0.9, 0],[0.1, 0.5, 1], 0); c[i] = 0;});
		env_curve.value = c[0];
	    edit_env.value_([tmp2, e[0].levels]).curves_(c[0]);
	});

	edit_env = EnvelopeView(edit_window, Rect(150, 0, 400, 400)).resize_(5)
	    .drawLines_(true)
		.selectionColor_(Color.red)
		.drawRects_(true)
		.resize_(5)
		.step_(0.05)
		.thumbSize_(5)
	    .action_({arg b; var tmp;
		    // Truncate current element to match Env requirements
		    tmp = b.value[0];
		    tmp.removeAt(0);
		    // Generate envs from values
		    for(0, n-1, {arg i; e[i]=Env(b.value[1], tmp, c[0])});
		})
	    .value_([tmp2, e[0].levels]).curves_(c[0]);
});
//RANDOMIZE
randomize = Button(w_main, Rect(10, 110, 80, 20));
randomize.string = "RANDOMIZE";
randomize.action_({
	for(0, n-1, {arg i; a[i].value=rand(1.00);})
});
//AUTO RANDOMIZE
randomizeAuto = Button(w_main, Rect(10, 135, 80, 20));
randomizeAuto.string = "AUTO RAND";
randomizeAuto.action_({
	AppClock.sched(0.0,{ arg time;
		for(0, n-1, {arg i; a[i].value=rand(1.00); x[i] = {SinOsc.ar(f[i]+k[i].value)*(a[i].value/active)*EnvGen.kr(e[i], doneAction:2)}.play; l[i].string = f[i]+k[i].value;});
		rrand(2.0, 0.9);
	});
});
//STADIUM WAVE
wave = Button(w_main, Rect(10, 160, 80, 20));
wave.string = "WAVE";
wave.action_({
	for(0, n-1, {arg i; x[i] =Synth(\base).set(\freq, f[i].value, \mul, a[i].value/active);});
	AppClock.sched(0.0,{ arg time;
		for(0, n-1, {arg i; a[i].value=((1/2)*sin(2*pi*1*(i+time)/n)) + (1/2); x[i].set(\freq, f[i]+k[i].value, \mul, a[i].value/active);
			if(type.value == 0, {
				type.valueAction_(0);
			}, {type.valueAction_(1);});
		});
    0.01;
	});
});
//SHEPARD-RISSET GLISSANDO
gliss = Button(w_main, Rect(10, 185, 80, 20));
gliss.string = "SR GLISSANDO";
gliss.action_({
	var play, list;
	w_gliss = Window("Shepard-Risset Glissando", Rect(825,300,350,100)).background_(Color.white);

	list = EZListView(w_gliss, Rect(10, 10, 200, 80), "Choose starting frequencies", ["Notes [C, E, G]", "Harmonics of f0"]);

	play = Button(w_gliss, Rect(250, 10, 80, 80))
	.states_([ ["∞",Color.black, Color.green], ["Pause",Color.black, Color.red] ])
	.action_({
		if (play.value==1, {

			//CHORD is selected
			if(list.value==0, {
				var f01 = 523.25, n1 = 5, x1 = Array.newClear(n1), f1 = Array.newClear(n1);
				var f02 = 659.25, n2 = 5, x2 = Array.newClear(n2), f2 = Array.newClear(n2);
				var f03 = 783.99, n3 = 5, x3 = Array.newClear(n3), f3 = Array.newClear(n3);
				var tot = n1+n2+n3;
				for(0, n1-1, {arg i; f1[i]=f01*(i+1);}); for(0, n1-1, {arg i; x1[i]=Synth(\base).set(\freq, f1[i], \mul, 0);});
				for(0, n2-1, {arg i; f2[i]=f02*(i+1);}); for(0, n2-1, {arg i; x2[i]=Synth(\base).set(\freq, f2[i], \mul, 0);});
				for(0, n3-1, {arg i; f3[i]=f03*(i+1);}); for(0, n3-1, {arg i; x3[i]=Synth(\base).set(\freq, f3[i], \mul, 0);});

				AppClock.sched(0.0,{ arg time;

					for(0, n1-1, {arg i; var amp;
						if(    f1[i]==(f01*(n1+1)), { f1[i] = f01; }, { f1[i]=f1[i]+1; }    );
						if(    f1[i]<=((f01*(n1+1))/2), {amp = (f1[i]-f01)/((f01*(n1-1))/2); }, {amp = abs(f1[i]-(f01*(n1+1)))/((f01*(n1-1))/2);}    );
						x1[i].set(\freq, f1[i]+k[i].value, \mul, amp/tot);
					});
					for(0, n2-1, {arg i; var amp;
						if(    f2[i]==(f02*(n2+1)), { f2[i] = f02; }, { f2[i]=f2[i]+1; }    );
						if(    f2[i]<=((f02*(n2+1))/2), {amp = (f2[i]-f02)/((f02*(n2-1))/2); }, {amp = abs(f2[i]-(f02*(n2+1)))/((f02*(n2-1))/2);}    );
						x2[i].set(\freq, f2[i]+k[i].value, \mul, amp/tot);
					});
					for(0, n3-1, {arg i; var amp;
						if(    f3[i]==(f03*(n3+1)), { f3[i] = f03; }, { f3[i]=f3[i]+1; }    );
						if(    f3[i]<=((f03*(n3+1))/2), {amp = (f3[i]-f03)/((f03*(n3-1))/2); }, {amp = abs(f3[i]-(f03*(n3+1)))/((f03*(n3-1))/2);}    );
						x3[i].set(\freq, f3[i]+k[i].value, \mul, amp/tot);
					});

					0.01;
				});
			});


			//HARMONICS OF f0 is selected
			if(list.value==1, {
				f.postln;
				for(0, n-1, {arg i;
					x[i]=Synth(\base).set(\freq, f[i], \mul, 0);
				});
				AppClock.sched(0.0,{ arg time;
					for(0, n-1, {arg i; var amp;
						if(    f[i]==(f0*(n+1)), { f[i] = f0; }, { f[i]=f[i]+1; }    );
						if(    f[i]<=((f0*(n+1))/2), {amp = (f[i]-f0)/((f0*(n-1))/2); }, {amp = abs(f[i]-(f0*(n+1)))/((f0*(n-1))/2);}    );
						x[i].set(\freq, f[i], \mul, amp/n);
						a[i].value = amp;
					});
					f.postln;
					0.01;
				});
			});
		},{CmdPeriod.run;});
	});

	w_gliss.front;
	w_gliss.onClose_({CmdPeriod.run;});
	});
)

