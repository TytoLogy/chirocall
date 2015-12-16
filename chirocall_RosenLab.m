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
	global H
	
	%------------------------------------------------------------------
	% to record from 1 channel (AI1), set H.Nchannels to 1
	% to record from 2 channels (AI1 and AI2), set H.Nchannels to 2
	%------------------------------------------------------------------
	H.Nchannels = 1;
	H.Dnum = 'Dev1';
	%------------------------------------------------------------------
	% H.Fs is the sample rate in units of samples per second
	%------------------------------------------------------------------
	H.Fs = 250000;
	%------------------------------------------------------------------
	% SweepDuration is the duration to display in the ongoing 
	% data display window.
	%------------------------------------------------------------------
	H.SweepDuration = 500;
% 	H.DefaultOutputPath = pwd;
	H.DefaultOutputPath = 'D:\';
	H.DefaultOutputFile = ['ccdata_' date '.daq'];
	H.OutputFile = fullfile(H.DefaultOutputPath, H.DefaultOutputFile);
	
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
	set(H.f, 'ToolBar', 'none');
	set(H.f, 'MenuBar', 'none');

	% create monitor button
	H.monitor = uicontrol('Style', 'togglebutton', ...
									'String', 'monitor', ...
									'Position', monitorbuttonpos, ...
									'FontSize', 12, ...
									'Callback', {@monitor_callback});
	% create record button
	H.record = uicontrol('Style', 'togglebutton', ...
									'String', 'record', ...
									'Position', recordbuttonpos, ...
									'FontSize', 12, ...
									'Callback', {@record_callback});

	if nargout
		varargout{1} = H;
	end
end

function monitor_callback(hObject, eventdata)
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	% Need to do different things depending on state of button
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	global H
	
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

		%-------------------------------------------------------------
		% Start DAQ things
		%-------------------------------------------------------------
		% Initialize the NI device
		try
			H.NI = ai_init('NI', H.Dnum, H.Nchannels);
		catch errMsg
			disp('error initializing NI device')
			init_status = 0;
			update_ui_str(H.monitor, 'Monitor');
			enable_ui(H.record);
			set(H.monitor, 'FontAngle', 'normal');
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
		set(H.NI.ai, 'InputType', 'SingleEnded');

		%------------------------------------------------------------------------
		% EVENT and CALLBACK PARAMETERS
		%------------------------------------------------------------------------
		% first, set the object to call the SamplesAcquiredFunction when
		% BufferSize # of points are available
		set(H.NI.ai, 'SamplesAcquiredFcnCount', ms2samples(H.SweepDuration, H.Fs));
	
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
		H.SweepPoints = length(zeroacq);
		H.tvec_acq = 1000*dt*(0:(H.SweepPoints-1));
		
		%-------------------------------------------------------
		% create arrays for plotting and plot them
		%-------------------------------------------------------
		% acq
		H.AI0data = zeroacq;
		if H.Nchannels == 2
			H.AI1data = zeroacq;
		end
		
		%----------------------------------------------------------------
		% plot null data, save handles in H struct for time-domain plots
		%----------------------------------------------------------------
		% response
		H.ai0axes = subplot(1, H.Nchannels, 1);
		H.ai0plot = plot(H.ai0axes, H.tvec_acq, H.AI0data, 'g');
		set(H.ai0plot, 'XDataSource', 'H.tvec_acq', 'YDataSource', 'H.AI0data');
		title('Channel AI0');
		if H.Nchannels == 2
			H.ai1axes = subplot(1, H.Nchannels, 2);
			H.ai1plot = plot(H.ai1axes, H.tvec_acq, H.AI1data, 'r');
			set(H.ai1plot, 'XDataSource', 'H.tvec_acq', 'YDataSource', 'H.AI1data');
			title('Channel AI1');
		end

		%-------------------------------------------------------
		% plot null data, save handles for frequency-domain plots
		%-------------------------------------------------------

		% provide callback function
		set(H.NI.ai, 'SamplesAcquiredFcn', {@plot_data});

		%START ACQUIRING
		start(H.NI.ai);
		trigger(H.NI.ai);

	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	%***** stop monitor
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	else
		%------------------------------------------------------------------------
		%------------------------------------------------------------------------
		% clean up
		%------------------------------------------------------------------------
		%------------------------------------------------------------------------
		disp('...closing NI devices...');
		% stop acquiring
		try
			stop(H.NI.ai);
		catch errEvent
			fprintf('problem stopping!\n\n\n')
			disp(errEvent)
			return
		end
		% get event log
		% EventLog = showdaqevents(handles.iodev.NI.ai);

		% delete and clear ai and ch0 object
		delete(H.NI.ai);
		clear H.NI.ai
		% update UI
		update_ui_str(H.monitor, 'monitor');
		set(H.monitor, 'FontAngle', 'normal', 'FontWeight', 'normal');
		enable_ui(H.record);
	end
	
end


function record_callback(hObject, eventdata)
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	% Need to do different things depending on state of button
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	global H
	currentState = read_ui_val(H.record);

	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	%***** start record
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	if currentState == 1
		%-------------------------------------------------------------
		% get file to which data will be saved
		%-------------------------------------------------------------				
		[fname, fpath] = uiputfile(H.OutputFile, 'Write Data to ...' );
		if isequal(fname, 0) || isequal(fpath, 0)
			disp('Cancelling record...')
			update_ui_val(H.record, 0);
			return
		else
			H.OutputFile = fullfile(fpath, fname);
			disp(['Data will be written to ', H.OutputFile]);
			% set up gui for record state
			update_ui_str(H.record, 'record ON');
			set(H.record, 'FontAngle', 'italic', 'FontWeight', 'bold');
			disable_ui(H.monitor);
		end
		
		%-------------------------------------------------------------
		% Start DAQ things
		%-------------------------------------------------------------
		% Initialize the NI device
		try
			H.NI = ai_init('NI', H.Dnum, H.Nchannels);
		catch errMsg
			disp('error initializing NI device')
			init_status = 0;
			update_ui_str(H.monitor, 'Monitor');
			enable_ui(H.record);
			set(H.monitor, 'FontAngle', 'normal');
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
		set(H.NI.ai, 'InputType', 'SingleEnded');

		%------------------------------------------------------------------------
		% EVENT and CALLBACK PARAMETERS
		%------------------------------------------------------------------------
		% first, set the object to call the SamplesAcquiredFunction when
		% BufferSize # of points are available
		set(H.NI.ai, 'SamplesAcquiredFcnCount', ...
									ms2samples(H.SweepDuration, H.Fs));
	
		%-------------------------------------------------------
		% set logging mode
		%	'Disk'	sets logging mode to a file on disk 
		%							(specified by 'LogFileName)
		%	'Memory'	sets logging mode to memory only
		%	'Disk&Memory'	logs to file and memory
		%-------------------------------------------------------
		set(H.NI.ai, 'LoggingMode', 'Disk&Memory');
		
		%-------------------------------------------------------
		% set log to disk mode
		%	'Index'	appends an index number to the file
		%	'Overwrite'	overwrites file
		%-------------------------------------------------------		
		set(H.NI.ai, 'LogToDiskMode', 'Index');
		
		%-------------------------------------------------------
		% set logging file
		%-------------------------------------------------------		
		set(H.NI.ai, 'LogFileName', H.OutputFile);
		
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
		H.SweepPoints = length(zeroacq);
		H.tvec_acq = 1000*dt*(0:(H.SweepPoints-1));
		
		%-------------------------------------------------------
		% create arrays for plotting and plot them
		%-------------------------------------------------------
		% acq
		H.AI0data = zeroacq;
		if H.Nchannels == 2
			H.AI1data = zeroacq;
		end
		
		%----------------------------------------------------------------
		% plot null data, save handles in H struct for time-domain plots
		%----------------------------------------------------------------
		% response
		H.ai0axes = subplot(1, H.Nchannels, 1);
		H.ai0plot = plot(H.ai0axes, H.tvec_acq, H.AI0data, 'g');
		set(H.ai0plot, 'XDataSource', 'H.tvec_acq', 'YDataSource', 'H.AI0data');
		title('Channel AI0');
		if H.Nchannels == 2
			H.ai1axes = subplot(1, H.Nchannels, 2);
			H.ai1plot = plot(H.ai1axes, H.tvec_acq, H.AI1data, 'r');
			set(H.ai1plot, 'XDataSource', 'H.tvec_acq', 'YDataSource', 'H.AI1data');
			title('Channel AI1');
		end
		
		%-------------------------------------------------------
		% plot null data, save handles for frequency-domain plots
		%-------------------------------------------------------

		% provide callback function
		set(H.NI.ai, 'SamplesAcquiredFcn', {@plot_data});

		%START ACQUIRING
		start(H.NI.ai);
		trigger(H.NI.ai);
		
		
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	%***** stop record
	%------------------------------------------------------------------------
	%------------------------------------------------------------------------
	else
		% stop acquiring
		disp('...closing NI devices...');
		try
			stop(H.NI.ai);
		catch errEvent
			fprintf('problem stopping!\n\n\n')
			disp(errEvent)
			return
		end
		% get event log
		% EventLog = showdaqevents(handles.iodev.NI.ai);

		% delete and clear ai and ch0 object
		delete(H.NI.ai);
		clear H.NI.ai

		% update UI
		update_ui_str(H.record, 'record');
		set(H.record, 'FontAngle', 'normal', 'FontWeight', 'normal');
		enable_ui(H.monitor);
	end
end

function plot_data(obj, event)
	global H
	
	% read data from ai object
	tmpdata = getdata(obj, H.SweepPoints);
	H.AI0data = tmpdata(:, 1);
	% update data plot
	refreshdata(H.ai0plot, 'caller');
	% do same for channel 2 if necessary
	if H.Nchannels == 2
		H.AI1data = tmpdata(:, 2);
		refreshdata(H.ai1plot, 'caller');
	end
end
