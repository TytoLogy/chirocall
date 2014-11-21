%readcall
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


defaultpath = pwd;
defaultfile = ['ccdata_' date '.daq'];
infile = fullfile(defaultpath, defaultfile);

%-------------------------------------------------------------
% get file from which data will be read
%-------------------------------------------------------------				
[fname, fpath] = uigetfile(infile, 'Read Data from ...' );
if isequal(fname, 0) || isequal(fpath, 0)
	disp('Cancelling ...')
	return
else
	infile = fullfile(fpath, fname);
	disp(['Data will be read from ', infile]);
end

% read data
[data, time, abstime, events, info] = daqread(infile);

npts = length(data);
Fs = info.ObjInfo.SampleRate;
dt = 1./Fs;

fprintf('File %s has:\n', fname);
fprintf('\t%d samples (%f seconds) of data.\n', npts, npts * dt);
fprintf('\tsample rate = %f samples/sec\n', Fs);