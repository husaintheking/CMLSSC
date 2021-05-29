//Connect OSC in TouchOsc with port:57120
(
s.waitForBoot
({
//MIDI connection
MIDIClient.init;
MIDIIn.connectAll;

//******************** GROUPS AND BUSSES **********************************
~synthGroup = Group.new(s);
~myGroup = Group.after(~synthGroup);
~fxBus = Bus.audio(s, 2);
s.queryAllNodes;

//******************** ENVELOPE FUNCTION **********************************
(
~adsrFunc = {
	arg attack, decay, sustain, release, curve, gate;
	var env;

	env = EnvGen.ar(Env.adsr(attack, decay, sustain, release, 1, curve), gate, doneAction:2);
}
);


//******************** DEFINITIONS OF SYNTHESIZERS' ALGORITHMS **********************************
(
SynthDef("basic", {
	arg index_basic, harm_basic, att_c, att_m, dec_c, dec_m, sus_c, sus_m, rel_c, rel_m, curve_c, curve_m, freq_c, amp, gate;
	var freq_m, modIndex, modSig, out, env_c, env_m;

	freq_m = harm_basic * freq_c;
	modIndex = freq_m * index_basic;
    env_c = ~adsrFunc.value(att_c, dec_c, sus_c, rel_c, curve_c, gate);
    env_m = ~adsrFunc.value(att_m, dec_m, sus_m, rel_m, curve_m, gate);

	modSig = SinOsc.ar(freq_m, 0, modIndex) * env_m;

	out = SinOsc.ar(freq_c + modSig, 0, amp) * env_c;

	Out.ar(~fxBus, out);

}).add;
);


(
SynthDef("compound", {
	arg index1_comp, index2_comp, harm1_comp, harm2_comp, att_c, att_m, dec_c, dec_m, sus_c, sus_m, rel_c, rel_m, curve_c, curve_m, freq_c, amp, gate;
	var freq_m1, freq_m2, modIndex1, modIndex2, modSig1, modSig2, modulator, out, env_c, env_m;

	freq_m1 = harm1_comp * freq_c;
	freq_m2 = harm2_comp * freq_c;

	modIndex1 = freq_m1 * index1_comp;
	modIndex2 = freq_m2 * index2_comp;

	env_c = ~adsrFunc.value(att_c, dec_c, sus_c, rel_c, curve_c, gate);
    env_m = ~adsrFunc.value(att_m, dec_m, sus_m, rel_m, curve_m, gate);

	modSig1 = SinOsc.ar(freq_m1, 0, modIndex1);
	modSig2 = SinOsc.ar(freq_m2, 0, modIndex2);

	modulator = Mix.new([modSig1, modSig2]) * env_m;

	out = SinOsc.ar(freq_c + modulator, 0, amp) * env_c;

	Out.ar(~fxBus, out);

}).add;
);


(
SynthDef("nested", {
	arg index1_nest, index2_nest, harm1_nest, harm2_nest, att_c, att_m, dec_c, dec_m, sus_c, sus_m, rel_c, rel_m, curve_c, curve_m, freq_c, amp, gate;
	var freq_m1, freq_m2, modIndex1, modIndex2, modSig1, modSig2, out, env_c, env_m;

	freq_m1 = harm1_nest * freq_c;
	freq_m2 = harm2_nest * freq_c;

	modIndex1 = freq_m1 * index1_nest;
	modIndex2 = freq_m2 * index2_nest;

	env_c = ~adsrFunc.value(att_c, dec_c, sus_c, rel_c, curve_c, gate);
    env_m = ~adsrFunc.value(att_m, dec_m, sus_m, rel_m, curve_m, gate);

	modSig1 = SinOsc.ar(freq_m1, 0, modIndex1);
	modSig2 = SinOsc.ar(freq_m2 + modSig1, 0, modIndex2) * env_m;

	out = SinOsc.ar(freq_c + modSig2, 0, amp) * env_c;

	Out.ar(~fxBus, out);

}).add;
);


(
SynthDef("feedback", {
  arg index_feed, harm_feed, att_c, att_m, dec_c, dec_m, sus_c, sus_m, rel_c, rel_m, curve_c, curve_m, feedback, freq_c, amp, gate;
  var freq_m, modIndex, modSig, carrierFeedback, out, pan, env_c, env_m;

  freq_m = harm_feed * freq_c;
  modIndex = freq_c * index_feed;

  env_c = ~adsrFunc.value(att_c, dec_c, sus_c, rel_c, curve_c, gate);
  env_m = ~adsrFunc.value(att_m, dec_m, sus_m, rel_m, curve_m, gate);

  carrierFeedback = LocalIn.ar(2);

  modSig = SinOsc.ar(freq_m + (carrierFeedback * freq_c * feedback), 0, modIndex) * env_m;

  out = SinOsc.ar(freq_c + modSig, 0, amp);

  LocalOut.ar(out);

  Out.ar(~fxBus, out) * env_c;

}).add;
);


//*********************************** EFFECTS' DEFINITION *************************************************


(
SynthDef(\delay, {
	arg time_delay = 0, wet_delay = 0;
	var input, wet_sig, dry_sig, out;

	input = In.ar(~fxBus, 2);
	wet_sig = input * wet_delay;
	dry_sig = input * (1 - wet_delay);

	wet_sig = CombC.ar(wet_sig, 5, time_delay); // senza decay time perché c'è già l'enveloppe che se ne occupa!

	out = Mix.new([dry_sig, wet_sig]);
	Out.ar(~fxBus, out);

}).add;
);


(
SynthDef(\reverb, {
	arg wet_reverb, room, damp;
	var out, input;

	input = In.ar(~fxBus, 2);
	out = FreeVerb.ar(input, wet_reverb, room, damp);

	Out.ar(~fxBus, out);

}).add;
);



// **************************** MASTER FADER ******************************
(
SynthDef(\master, {
	arg master_gain = 1;
	var input, out, outbus = 0;

	input = In.ar(~fxBus, 2);
	out = input * master_gain;


	Out.ar(0, out * 0.1);
}).add;
);

//******************** INIT **********************************

~delay      = Synth.head(~myGroup, \delay);
~reverb     = Synth.after(~delay, \reverb);

~master = Synth.tail(~myGroup, \master);

~notes = Array.newClear(128);

~synth_type = "basic";
~octave = 0;


//BASIC FM
~index_basic = 1;
~harm_basic  = 1;

//COMPOUND FM
~index1_comp = 1;
~index2_comp = 1;
~harm1_comp  = 1;
~harm2_comp  = 1;

//NESTED FM
~index1_nest = 1;
~index2_nest = 1;
~harm1_nest  = 1;
~harm2_nest  = 1;

//FEEDBACK FM
~index_feed = 1;
~harm_feed  = 1;
~feedback = 1;

//ENV carrier params
~att_c = 0.5;
~dec_c = 0.5;
~sus_c = 1;
~rel_c = 1;
~curve_c = 0;

//ENV modulator params
~att_m = 0.5;
~dec_m = 0.5;
~sus_m = 1;
~rel_m = 1;
~curve_m = 0;

//******************** COMMUNICATION **********************************
(
//*******************************SYNTHS

//BASIC FM
		OSCdef.new( \control1,  { arg msg, time, addr, port; ~index_basic = msg[1].postln; }, '/index_basic');  //[0, 10]
		OSCdef.new( \control2,  { arg msg, time, addr, port; ~harm_basic  = msg[1]; }, '/harm_basic');   //[0.5, 2]

//COMPOUND FM
		OSCdef.new( \control3,  { arg msg, time, addr, port; ~index1_comp = msg[1]; }, '/index1_comp');  //[0, 10]
		OSCdef.new( \control4,  { arg msg, time, addr, port; ~index2_comp = msg[1]; }, '/index2_comp');  //[0, 10]
		OSCdef.new( \control5,  { arg msg, time, addr, port; ~harm1_comp  = msg[1]; }, '/harm1_comp');   //[0.5, 2]
		OSCdef.new( \control6,  { arg msg, time, addr, port; ~harm2_comp  = msg[1]; }, '/harm2_comp');   //[0.5, 2]

//NESTED FM
		OSCdef.new( \control7,  { arg msg, time, addr, port; ~index1_nest = msg[1]; }, '/index1_nest');  //
		OSCdef.new( \control8,  { arg msg, time, addr, port; ~index2_nest = msg[1]; }, '/index2_nest');  //
		OSCdef.new( \control9,  { arg msg, time, addr, port; ~harm1_nest  = msg[1]; }, '/harm1_nest');   //
		OSCdef.new( \control10, { arg msg, time, addr, port; ~harm2_nest  = msg[1]; }, '/harm2_nest');   //

//FEEDBACK FM
		OSCdef.new( \control11, { arg msg, time, addr, port; ~index_feed = msg[1]; }, '/index_feed');    //
		OSCdef.new( \control12, { arg msg, time, addr, port; ~harm_feed  = msg[1]; }, '/harm_feed');     //

//ENVELOPE CARRIER
		OSCdef.new( \control13,  { arg msg, time, addr, port; ~att_c = msg[1]; }, '/att_c');             //[0, 2]
		OSCdef.new( \control14, { arg msg, time, addr, port; ~dec_c = msg[1]; }, '/dec_c');              //[0, 2]
		OSCdef.new( \control15, { arg msg, time, addr, port; ~sus_c = msg[1]; }, '/sus_c');              //[0, 1]
		OSCdef.new( \control16, { arg msg, time, addr, port; ~rel_c = msg[1]; }, '/rel_c');              //[0, 5]
		OSCdef.new( \control17, { arg msg, time, addr, port; ~curve_c = msg[1]; }, '/curve_c');          //[-10, 10]

//ENVELOPE MODULATOR
		OSCdef.new( \control18, { arg msg, time, addr, port; ~att_m = msg[1]; }, '/att_m');              //[0, 2]
		OSCdef.new( \control19, { arg msg, time, addr, port; ~dec_m = msg[1]; }, '/dec_m');              //[0, 2]
		OSCdef.new( \control20, { arg msg, time, addr, port; ~sus_m = msg[1]; }, '/sus_m');              //[0, 1]
		OSCdef.new( \control21, { arg msg, time, addr, port; ~rel_m = msg[1]; }, '/rel_m');              //[0, 5]
		OSCdef.new( \control22, { arg msg, time, addr, port; ~curve_m = msg[1]; }, '/curve_m');          //[-10, 10]



//*******************************EFFECTS

//DELAY
        OSCdef.new( \control28, { arg msg, time, addr, port; ~delay.set(\wet_delay, msg[1]); }, '/wet_delay');	    //[0, 1]
        OSCdef.new( \control29, { arg msg, time, addr, port; ~delay.set(\time_delay,msg[1]); }, '/time_delay');	//[0, 5] sec

//REVERB
        OSCdef.new( \control30, { arg msg, time, addr, port; ~reverb.set(\wet_reverb, msg[1]); }, '/wet_reverb');   //[0, 1]
        OSCdef.new( \control31, { arg msg, time, addr, port; ~reverb.set(\room, msg[1]); }, '/room');               //[0, 1]
        OSCdef.new( \control32, { arg msg, time, addr, port; ~reverb.set(\damp, msg[1]); }, '/damp');             //[0, 1]


//*******************************
//OCTAVE
		OSCdef.new( \control45,{ arg msg, time, addr, port; if(msg[1]==1)
			{if(~octave < 3) {~octave = ~octave + 1;} }; }, '/octave+');
		OSCdef.new( \control46,{ arg msg, time, addr, port; if(msg[1]==1)
			{if(~octave > -3) {~octave = ~octave - 1;} }; }, '/octave-');

//SYNTH TYPE
		OSCdef.new( \control47, { arg msg, time, addr, port; ~synth_type = msg[1]; }, '/synth');    //[basic, compound, nested, feedback]

//MASTER
		OSCdef.new( \control48, { arg msg, time, addr, port; ~master.set(\master_gain,msg[1]); }, '/master');       //[0, 1]
);



//********************************************* PROCESSING *****************************************************


(
//NOTE ON manager
MIDIdef.noteOn(\noteOntest, { arg vel, nn, chan, src;

	(
			~notes [nn] = Synth.head (~synthGroup, ~synth_type,
        [
			[vel, nn, chan, src].postln;
				\freq_c, (nn + (~octave*12)).midicps,
            \amp, vel.linexp(1, 127, 0.01, 0.5),
			\gate, 1,

			\att_c, ~att_c,
			\att_m, ~att_m,
			\dec_c, ~dec_c,
			\dec_m, ~dec_m,
			\sus_c, ~sus_c,
			\sus_m, ~sus_m,
			\rel_c, ~rel_c,
			\rel_m, ~rel_m,
			\curve_c, ~curve_c,
			\curve_m, ~curve_m,

			//BASIC FM
			\index_basic, ~index_basic,
			\harm_basic, ~harm_basic,

			//COMPOUND FM
			\index1_comp, ~index1_comp,
			\index2_comp, ~index2_comp,
			\harm1_comp, ~harm1_comp,
			\harm2_comp, ~harm2_comp,

			//NESTED FM
			\index1_nest, ~index1_nest,
			\index2_nest, ~index2_nest,
			\harm1_nest, ~harm1_nest,
			\harm2_nest, ~harm2_nest,

			//FEEDBACK FM
			\index_feed, ~index_feed,
			\harm_feed, ~harm_feed,
			\feedback, ~feedback

        ]);

		);


//NOTE OFF manager
(
MIDIdef.noteOff(\noteoff, {arg vel, nn;
	~notes[nn].set(\gate, 0);
	~notes[nn] = nil; })

);


})
);
})
)



