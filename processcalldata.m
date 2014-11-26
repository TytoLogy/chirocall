function varargout = processcalldata
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
%------------------------------------------------------------------------

%-------------------------------------------------------------
% some defaults
%-------------------------------------------------------------
sepstr = '--------------------------------------------------------------------';
default_chunk_min = 0.5;

%-------------------------------------------------------------
% get file from which data will be read
%-------------------------------------------------------------				
[fname, fpath] = uigetfile( ...
									{'*.daq',	'DAQ toolbox file'; ...
									 '*.*',		'All Files'	}, ...
									'Select Data File', pwd);
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
% get output directory/file information
%-------------------------------------------------------------
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
% report to user
%-------------------------------------------------------------
fprintf('\n\n');
fprintf('%s\n', sepstr);
fprintf('File %s has:\n', fname);
fprintf('\t%d channels of data.\n', max(size(info.ObjInfo.Channel)));
fprintf('\t%d samples (%f seconds) of data.\n', npts, net_time);
fprintf('\tsample rate = %f samples/sec\n', Fs);
fprintf('%s\n', sepstr);

%-------------------------------------------------------------
% ask user for duration (in seconds) into which the original
% data stream should be chunked
%-------------------------------------------------------------
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
	% first normalize data to +/- 0.95 V max to avoid clipping
	%------------------------------------------------------------
	% ensure data are organized with channels in rows
	[nrows, ncols] = size(data);
	if ncols > nrows
		% if # of columns > # of rows, transpose the data so that
		% samples are in rows, channels are in columns
		data = data';
	end
	clear ncols nrows
	
	% normalize data by channel
	[nsamples, nchannels] = size(data);
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

