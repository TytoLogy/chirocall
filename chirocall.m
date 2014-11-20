function varargout = chirocall(varargin)
%------------------------------------------------------------------------
% chirocall.m
%------------------------------------------------------------------------
% 
%------------------------------------------------------------------------
% See also: 
%------------------------------------------------------------------------

%------------------------------------------------------------------------
% Sharad J. Shanbhag
% sshanbhag@neomed.edu
%------------------------------------------------------------------------
% Created: 20 November 2014 (SJs)
% 	- adapted from NICal_Monitor.m script
%
% Revisions:
%------------------------------------------------------------------------

	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	% Global Constants
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	H.Dnum = 1;

	H.SweepDuration = 500;

	%---------------------------------------------
	%---------------------------------------------
	% Microphone information
	%---------------------------------------------
	%---------------------------------------------
	% microphone sensitivity in Volts / Pascal (from Nexxus Amplifier)
	CalMic_sense = 1;

	%-------------------------------------------------------------
	% need some conversion factors
	%-------------------------------------------------------------
	% pre-compute the V -> Pa conversion factor
	H.VtoPa = (CalMic_sense^-1);

	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	% Create GUI
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	figpos = [400 550 360 140];
	recordbuttonpos = [20	20	150	100];
	monitorbuttonpos = [190	20	150	100];

	H.f = figure;
	set(H.f, 'Position', figpos);
	set(H.f, 'Name', 'ChiroCall');

	% create monitor button
	H.monitor = uicontrol('Style', 'togglebutton', ...
									'String', 'monitor', ...
									'Position', monitorbuttonpos, ...
									'FontSize', 12);

	% create record button
	H.record = uicontrol('Style', 'togglebutton', ...
									'String', 'record', ...
									'Position', recordbuttonpos, ...
									'FontSize', 12); 

	set(H.monitor, 'Callback', {@monitor_callback, H});
	set(H.record, 'Callback', {@record_callback, H});

	if nargout
		varargout{1} = H;
	end
end

function monitor_callback(hObject, eventdata, H)
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	% Need to do different things depending on state of button
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	currentState = read_ui_val(H.monitor);

	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	%***** start monitor
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	if currentState == 1
		update_ui_str(H.monitor, 'monitor ON');
		set(H.monitor, 'FontAngle', 'italic', 'FontWeight', 'bold');
		disable_ui(H.record);
		guidata(hObject, H)

		%-------------------------------------------------------------
		% Start DAQ things
		%-------------------------------------------------------------
		% Initialize the NI device
		try
			H.NI = ai_init('NI', H.Dnum);
			guidata(hObject, H)
		catch errMsg
			disp('error initializing NI device')
			init_status = 0;
			update_ui_str(H.monitor, 'Monitor');
			enable_ui(H.record);
			set(H.monitor, 'FontAngle', 'normal');
			guidata(hObject, H);
			return
		end

		%------------------------------------------------------
		% AI subsystem
		%------------------------------------------------------
		set(H.NI.ai, 'SampleRate', H.Fs);
		ActualRate = get(H.NI.ai, 'SampleRate');
		if H.Fs ~= ActualRate
			warning('chirocall:NIDAQ', ...
						'Requested ai Fs (%f) ~= ActualRate (%f)', H.Fs, ActualRate);
		end
		H.Fs = ActualRate;

		%-----------------------------------------------------------------------
		%-----------------------------------------------------------------------
		% set input range
		%-----------------------------------------------------------------------
		%-----------------------------------------------------------------------
		% range needs to be in [RangeMin RangeMax] format
		aiaoRange = 5 * [-1 1];
		% set analog input range (might be overkill to set 
		% InputRange, SensorRange and UnitsRange, but is seems to work)
		for n = 1:length(H.NI.ai.Channel)
			H.NI.ai.Channel(n).InputRange = aiaoRange;
			H.NI.ai.Channel(n).SensorRange = aiaoRange;
			H.NI.ai.Channel(n).UnitsRange = aiaoRange;
		end

		% set SamplesPerTrigger to Inf for continous acquisition
		set(H.NI.ai, 'SamplesPerTrigger', Inf);
		% set TriggerType to 'Manual' so that program starts acquisition
		set(H.NI.ai, 'TriggerType', 'Manual');
		% set input type to single ended
		set(H.ai, 'InputType', 'SingleEnded');

		%------------------------------------------------------------------------
		% EVENT and CALLBACK PARAMETERS
		%------------------------------------------------------------------------
		% first, set the object to call the SamplesAcquiredFunction when
		% BufferSize # of points are available
		set(H.NI.ai, 'SamplesAcquiredFcnCount', ms2samples(H.SweepDuration, H.Fs));
		% provide callback function
		set(H.ai, 'SamplesAcquiredFcn', {@acquire_callback, H});
	
		%-------------------------------------------------------
		% set logging mode
		%	'Disk'	sets logging mode to a file on disk (specified by 'LogFileName)
		%	'Memory'	sets logging mode to memory only
		%	'Disk&Memory'	logs to file and memory
		%-------------------------------------------------------
		set(H.NI.ai, 'LoggingMode', 'Memory');
		%-------------------------------------------------------
		% set channel skew mode to Equisample
		%-------------------------------------------------------
		set(H.NI.ai, 'ChannelSkewMode', 'Equisample');
		%-------------------------------------------------------
		% sample interval
		%-------------------------------------------------------
		dt = 1/H.Fs;

		%-----------------------------------------------------------------------
		% create null acq and time vectors for plots, set up plots
		%-----------------------------------------------------------------------
		% to speed up plotting, the vectors Lacq, Racq, tvec_acq, L/Rfft, fvec
		% are pre-allocated and then those arrys are used as XDataSource and
		% YDataSource for the respective plots
		%-----------------------------------------------------------------------
		%-----------------------------------------------------------------------
		% create figure
		figH = figure;
		
		% time vector for stimulus plots
		zeroacq = syn_null(H.SweepDuration, H.Fs, 0);
		SweepPoints = length(zeroacq);
		tvec_acq = 1000*dt*(0:(SweepPoints-1));
		
		%-------------------------------------------------------
		% create arrays for plotting and plot them
		%-------------------------------------------------------
		% acq
		AI0data = zeroacq;
		AI1data = zeroacq;
		
		%----------------------------------------------------------------
		% plot null data, save handles in H struct for time-domain plots
		%----------------------------------------------------------------
		% response
		ai0plot = subplot(2,2,1);
		plot(ai0plot, tvec_acq, AI0data, 'g');
		set(ai0plot, 'XDataSource', 'tvec_acq', 'YDataSource', 'AI0data');
		ai1plot = subplot(2,2,2);
		plot(ai1plot, tvec_acq, Racq, 'r');
		set(ai1plot, 'XDataSource', 'tvec_acq', 'YDataSource', 'AI1data');

		%-------------------------------------------------------
		% plot null data, save handles for frequency-domain plots
		%-------------------------------------------------------

		%-------------------------------------------------------
		% update handles
		%-------------------------------------------------------
		guidata(hObject, H);

		%START ACQUIRING
		start(H.NI.ai);
		trigger(H.NI.ai);
		guidata(hObject, H);

	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	%***** stop monitor
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	else
		update_ui_str(H.monitor, 'monitor');
		set(H.monitor, 'FontAngle', 'normal', 'FontWeight', 'normal');
		guidata(hObject, H);
		%------------------------------------------------------------------------
		%------------------------------------------------------------------------
		% clean up
		%------------------------------------------------------------------------
		%------------------------------------------------------------------------
		disp('...closing NI devices...');
		% stop acquiring
		stop(H.NI.ai);
		% get event log
		% EventLog = showdaqevents(handles.iodev.NI.ai);

		% delete and clear ai and ch0 object
		delete(H.NI.ai);
		clear H.NI.ai

		enable_ui(H.record);
	end
	
end


function record_callback(hObject, eventdata, H)
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	% Need to do different things depending on state of button
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	currentState = read_ui_val(H.record);

	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	%***** start record
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	if currentState == 1
		update_ui_str(H.record, 'record ON');
		set(H.record, 'FontAngle', 'italic', 'FontWeight', 'bold');
		disable_ui(H.monitor);
		guidata(hObject, H)
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	%***** stop record
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	else
		update_ui_str(H.record, 'record');
		set(H.record, 'FontAngle', 'normal', 'FontWeight', 'normal');
		enable_ui(H.monitor);
		guidata(hObject, H);
	end
end