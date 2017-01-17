function varargout = processcalldata(varargin)
%------------------------------------------------------------------------
% readcall.m
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
%
% Revisions:
%	17 Dec 2014 (SJS): 
%	 -	moved some of the defaults to processcalldata_settings
%	 -	implemented bandpass filtering of data
%------------------------------------------------------------------------

%-------------------------------------------------------------
% some local defaults
%-------------------------------------------------------------
sepstr = '--------------------------------------------------------------------';

%-------------------------------------------------------------
% load settings
%-------------------------------------------------------------
processcalldata_settings;

%-------------------------------------------------------------
% check inputs, get input filename
%-------------------------------------------------------------
% initialize fname and fpath (for input daq file)
fname = 0;
fpath = 0;

if nargin == 1
	%-------------------------------------------------------------
	% check if user-provided file exists
	%-------------------------------------------------------------
	if ~exist(varargin{1}, 'file')
		% bad user
		error('%s: file not found (%s)', mfilename, varargin{1});
	else
		% good user
		[fpath, fname, fext] = fileparts(varargin{1})
		if ~strcmpi(fext, '.daq')
			error('%s: input file must be of type ''.daq''', mfilename);
		end
	end
		
elseif nargin == 0
	%-------------------------------------------------------------
	% get file from which data will be read
	%-------------------------------------------------------------				
	[fname, fpath] = uigetfile( ...
										{'*.daq',	'DAQ toolbox file'; ...
										 '*.*',		'All Files'	}, ...
										'Select Data File', pwd);
else
	%-------------------------------------------------------------
	% bad
	%-------------------------------------------------------------
	error('%s: invalid input argument(s)', mfilename);
end

%-------------------------------------------------------------
% load file
%-------------------------------------------------------------
if isequal(fname, 0) || isequal(fpath, 0)
	disp('Cancelling ...')
	return
else
	infile = fullfile(fpath, fname);
	fprintf('\n\n')
	fprintf('%s\n', sepstr);
	disp(['Data will be read from ', infile]);
	fprintf('%s\n', sepstr);
	[outpath, outfile] = fileparts(infile);
	outfile = [outfile '.wav'];
end


%-------------------------------------------------------------
% read data information
%-------------------------------------------------------------
info = daqread(infile, 'info');

%-------------------------------------------------------------
% get sample rate and # of points
%-------------------------------------------------------------
npts = info.ObjInfo.SamplesAcquired;
Fs = info.ObjInfo.SampleRate;
dt = 1./Fs;
net_time = dt * npts;
if net_time < default_chunk_min
	default_chunk_min = dt;
end
default_chunk = floor(0.5 * net_time);
if default_chunk == 0
	default_chunk = 0.5 * net_time;
end

%-------------------------------------------------------------
% get filter
%-------------------------------------------------------------
if strcmpi(FILTER_DATA, 'yes')
	filter_coeffs = get_filter(Fs);
end

%-------------------------------------------------------------
% report to user
%-------------------------------------------------------------
fprintf('\n\n');
fprintf('%s\n', sepstr);
fprintf('File %s has:\n', infile);
fprintf('\t%d channels of data.\n', max(size(info.ObjInfo.Channel)));
fprintf('\t%d samples (%f seconds) of data.\n', npts, net_time);
fprintf('\tsample rate = %f samples/sec\n', Fs);
fprintf('%s\n', sepstr);

%-------------------------------------------------------------
% plot values
%-------------------------------------------------------------
% plot using default chunks
nchunks = floor(net_time / default_chunk);
dchunks = cell(nchunks, 1);
plot_Fs = Fs / deci_factor;
plot_dt = 1 / plot_Fs;

% if nchunks == 0, use net_time
if nchunks == 0
	chunk_time = net_time;
	nchunks = 1;
else
	chunk_time = default_chunk;
end
% get remainder
rem_time = rem(net_time, chunk_time);
% if chunks divide evenly, no need to deal with remaining "chunk"
if rem_time == 0
	time_chunks = zeros(nchunks, 2);
	for n = 1:nchunks
		time_chunks(n, :) = [(n - 1) * chunk_time, n * chunk_time];
	end
else
	% otherwise, store remainder in an additional "chunk"
	time_chunks = zeros(nchunks + 1, 2);
	for n = 1:nchunks
		time_chunks(n, :) = [(n - 1) * chunk_time, n * chunk_time];
	end
	nchunks = nchunks + 1;
	% need to offset end (net_time) by one sample (dt) to avoid
	% error when reading...
	time_chunks(nchunks, :) = [(n * chunk_time), net_time - dt];	
end

[tmp, ~] = daqread(infile, 'Time', time_chunks(1, :));
%------------------------------------------------------------
% ensure data are organized with channels in rows
%------------------------------------------------------------
[nrows, ncols] = size(tmp);
% force tmp into column vector
if ncols > nrows
	% if # of columns > # of rows, transpose the data so that
	% samples are in rows, channels are in columns
	tmp = tmp';
end
clear ncols nrows
% size of data
[nsamples, nchannels] = size(tmp);

for n = 1:nchunks
	[tmp, ~] = daqread(infile, 'Time', time_chunks(n, :));
	[nrows, ncols] = size(tmp);
	if ncols > nrows
		% if # of columns > # of rows, transpose the data so that
		% samples are in rows, channels are in columns
		tmp = tmp';
	end
	% loop through channels
	for c = 1:nchannels
		% filter the data if specified
		if strcmpi(FILTER_DATA, 'yes')
			% sin2array only operates properly on row vectors
			tmp(:, c) = sin2array(tmp(:, c)', 0.5, Fs)';
			tmp(:, c) = filtfilt(filter_coeffs.b, filter_coeffs.a, tmp(:, c));
		end
	end
	% decimate the data
	dchunks{n} = decimate(tmp, deci_factor);
end

figH = figure;
% convert data to vector from cell
plot_data = cell2mat(dchunks);
plot_tvec = plot_dt * (0:(length(plot_data)-1));
% plot data
plot(plot_tvec, plot_data);
title(sprintf('%s', fname));
xlabel('Time (s)')
ylabel('Volts');
grid on


%-------------------------------------------------------------
% ask user if data should be automagically chunked
%-------------------------------------------------------------
fprintf('\n\n');
fprintf('%s\n', sepstr);
chunk_mode = query_userint('Auto-chunk the data', [0 1 0]);
fprintf('\n\n')

%-------------------------------------------------------------
% get output directory/file information
%-------------------------------------------------------------
clear fname fpath
[fname, fpath] = uiputfile('*.wav', 'Write Data To', ...
													fullfile(outpath, outfile));
if isequal(fname, 0) || isequal(fpath, 0)
	disp('Cancelling ...')
	return
else
	outpath = fpath;
	[tmp, outbase] = fileparts(fname);
	fprintf('\n\n')
	fprintf('%s\n', sepstr);
	fprintf('Data will be written to %s%s_<#>.wav\n', outpath, outbase);
	fprintf('%s\n', sepstr);
end

%-------------------------------------------------------------
% do what user asked
%-------------------------------------------------------------
if chunk_mode == 0
	fprintf('\n\n');
	fprintf('%s\n', sepstr);
	fprintf('Extracting single chunk of data\n')
	fprintf('%s\n', sepstr);
	
	% ask user for start and stop time of chunk
	time_chunks = zeros(1, 2);
	nchunks = 1;
	fprintf('\n\n');
	fprintf('%s\n', sepstr);
	time_chunks(1, 1) = query_uservar('Start time (seconds)', ...
								[0 net_time 0]);
	fprintf('\n');
	time_chunks(1, 2) = query_uservar('Start time (seconds)', ...
								[	(time_chunks(1, 1) + dt) ...
									net_time ...
									(time_chunks(1, 1) + dt)]);

	% report chunks to user
	fprintf('\n');
	fprintf('Data will be extracted from:\n');
	fprintf('\tStart Time:\t%.2f\n', time_chunks(1, 1));
	fprintf('\tEnd Time:\t%.2f\n', time_chunks(1, 2));
	fprintf('%s\n\n', sepstr);

	%-------------------------------------------------------------
	% read in chunks of data, write to wav files
	%-------------------------------------------------------------
	fprintf('%s\n', sepstr)
	fprintf('Reading and Converting data to .wav format...\n')
	fprintf('\tReading 1 Chunk (%f - %f sec) ...', ...
										time_chunks(1, 1), time_chunks(1, 2));
	[data, time] = daqread(infile, 'Time', time_chunks(1, :));
	fprintf(' ...done\n');
	outname = sprintf('%s.wav', outbase);
	outfile = fullfile(outpath, outname);
	fprintf('\tWriting Chunk to file %s ...', outfile);
	%------------------------------------------------------------
	% ensure data are organized with channels in rows
	%------------------------------------------------------------
	[nrows, ncols] = size(data);
	if ncols > nrows
		% if # of columns > # of rows, transpose the data so that
		% samples are in rows, channels are in columns
		data = data';
	end
	clear ncols nrows
	% size of data
	[nsamples, nchannels] = size(data);
	%------------------------------------------------------------
	% filter data if asked to do so
	%------------------------------------------------------------
	if strcmpi(FILTER_DATA, 'yes')
		for c = 1:nchannels
			% need to ramp data on/off to avoid transient nastiness
			data(:, c) = sin2array(data(:, c)', 0.5, Fs)';
			% then apply filter
			data(:, c) = filtfilt(filter_coeffs.b, filter_coeffs.a, data(:, c));
		end
	end
	%------------------------------------------------------------
	% normalize data to +/- 0.95 V max to avoid clipping
	%------------------------------------------------------------
	% normalize data by channel
	for c = 1:nchannels
		data(:, c) = 0.95 * normalize(data(:, c));
	end

	%------------------------------------------------------------
	% then write to wave file (use try... catch to trap errors)
	%------------------------------------------------------------
	try
		wavwrite(data, Fs, outfile);
	catch errEvent
		fprintf('\nProblem while writing to file %s\n', outfile)
		disp(errEvent)
		return
	end

	% done!
	fprintf('... done\n');

	%------------------------------------------------------------
	% store info in .mat file
	%------------------------------------------------------------
	matfile = fullfile(outpath, [outbase '_info.mat']);
	save(matfile, 'info', '-MAT');
	
	%------------------------------------------------------------
	% outputs
	%------------------------------------------------------------
	if nargout > 0
		varargout{1} = time_chunks;
	end
	if nargout > 1
		varargout{2} = info;
	end	
	
	
%------------------------------------------------------------
%------------------------------------------------------------
else
	%-------------------------------------------------------------
	% ask user for duration (in seconds) into which the original
	% data stream should be chunked
	%-------------------------------------------------------------
	fprintf('\n\n');
	fprintf('%s\n', sepstr);
	fprintf('Automagically extracting chunks of data\n');
	fprintf('%s\n', sepstr);
	
	fprintf('\n\n');
	fprintf('%s\n', sepstr);
	chunk_time = query_uservalue('Time (seconds) for dividing data', ...
											[default_chunk_min net_time default_chunk]);
	fprintf('\n\n')

	%-------------------------------------------------------------
	% determine chunks
	%-------------------------------------------------------------
	% find # of chunks
	nchunks = floor(net_time / chunk_time);
	% if nchunks == 0, use net_time
	if nchunks == 0
		fprintf('\n!!!!!!!!!!!!\nWarning: nchunks == 0\n');
		fprintf('\tSetting chunk time to net duration (%f)\n', net_time);
		chunk_time = net_time;
		nchunks = 1;
	end
	% get remainder
	rem_time = rem(net_time, chunk_time);
	% if chunks divide evenly, no need to deal with remaining "chunk"
	if rem_time == 0
		time_chunks = zeros(nchunks, 2);
		for n = 1:nchunks
			time_chunks(n, :) = [(n - 1) * chunk_time, n * chunk_time];
		end
	else
		% otherwise, store remainder in an additional "chunk"
		time_chunks = zeros(nchunks + 1, 2);
		for n = 1:nchunks
			time_chunks(n, :) = [(n - 1) * chunk_time, n * chunk_time];
		end
		nchunks = nchunks + 1;
		% need to offset end (net_time) by one sample (dt) to avoid
		% error when reading...
		time_chunks(nchunks, :) = [(n * chunk_time), net_time - dt];	
	end
	% report chunks to user
	fprintf('\n');
	fprintf('Data will be divided into %d "chunks"\n', nchunks);
	fprintf('\tChunk times (seconds):\n')
	for n = 1:nchunks
		fprintf('\t\t')
		fprintf('Chunk %d:\t%.2f - %.2f\n', n, time_chunks(n, 1), ...
															 time_chunks(n, 2) );
	end
	fprintf('%s\n\n', sepstr);

	%-------------------------------------------------------------
	% read in chunks of data, write to wav files
	%-------------------------------------------------------------
	fprintf('%s\n', sepstr)
	fprintf('Reading and Converting data to .wav format...\n')
	for n = 1:nchunks
		fprintf('\tReading Chunk %d (%f - %f sec) ...', ...
												n, time_chunks(n, 1), time_chunks(n, 2));
		[data, time] = daqread(infile, 'Time', time_chunks(n, :));
		fprintf(' ...done\n');
		outname = sprintf('%s_%d.wav', outbase, n);
		outfile = fullfile(outpath, outname);
		fprintf('\tWriting Chunk to file %s ...', outfile);
		
		%------------------------------------------------------------
		% ensure data are organized with channels in rows
		%------------------------------------------------------------
		[nrows, ncols] = size(data);
		if ncols > nrows
			% if # of columns > # of rows, transpose the data so that
			% samples are in rows, channels are in columns
			data = data';
		end
		clear ncols nrows
		% size of data
		[nsamples, nchannels] = size(data);
		%------------------------------------------------------------
		% filter data if asked to do so
		%------------------------------------------------------------
		if strcmpi(FILTER_DATA, 'yes')
			for c = 1:nchannels
				% need to ramp data on/off to avoid transient nastiness
				data(:, c) = sin2array(data(:, c)', 0.5, Fs)';
				% then apply filter
				data(:, c) = filtfilt(filter_coeffs.b, filter_coeffs.a, data(:, c));
			end
		end
		%------------------------------------------------------------
		% normalize data to +/- 0.95 V max to avoid clipping
		%------------------------------------------------------------
		% normalize data by channel
		for c = 1:nchannels
			data(:, c) = 0.95 * normalize(data(:, c));
		end

		%------------------------------------------------------------
		% then write to wave file (use try... catch to trap errors)
		%------------------------------------------------------------
		try
			wavwrite(data, Fs, outfile);
		catch errEvent
			fprintf('\nProblem while writing to file %s\n', outfile)
			disp(errEvent)
			return
		end

		% done!
		fprintf('... done\n');
	end

	%------------------------------------------------------------
	% store info in .mat file
	%------------------------------------------------------------
	matfile = fullfile(outpath, [outbase '_info.mat']);
	save(matfile, 'info', '-MAT');
	
	%------------------------------------------------------------
	% outputs
	%------------------------------------------------------------
	if nargout > 0
		varargout{1} = time_chunks;
	end
	if nargout > 1
		varargout{2} = info;
	end
end


