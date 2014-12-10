function [msg, varargout] = ai_stop(NI)
%--------------------------------------------------------------------------
% [msg, EventLog] = ai_stop.m
%--------------------------------------------------------------------------
% chirocall program
% TytoLogy Project
%--------------------------------------------------------------------------
% stops nidaq system for analog acq
%------------------------------------------------------------------------
% Input Arguments:
% 	NI		struct containing settings for requested type
% 		NI.ai		analog input object
% 		NI.chI	analog input channel object
% 
% Output Arguments:
%	msg	0 if no error
%	EventLog	NI-DAQ event log
%------------------------------------------------------------------------
% See also: NICal, chirocall, ai_init
%------------------------------------------------------------------------

%--------------------------------------------------------------------------
% Sharad J Shanbhag
% sshanbhag@neomed.edu
%--------------------------------------------------------------------------
% Created: 10 December 2014 (SJS)
% 
% Revisions:
%--------------------------------------------------------------------------

%------------------------------------------------------------------------
%------------------------------------------------------------------------
% check inputs
%------------------------------------------------------------------------
%------------------------------------------------------------------------
 
if nargin ~= 1
	error('%s: bad inputs', mfilename);
end

if ~isstruct(NI)
	error('%s: input is not struct', mfilename);
end

disp('...closing NI devices...');

%------------------------------------------------------------------------
%------------------------------------------------------------------------
% Now, Stop the NI board (PCIe-6351)
%------------------------------------------------------------------------
%------------------------------------------------------------------------

% stop acquiring
try
	stop(NI.ai);
catch errEvent
	fprintf('%s: problem stopping!\n\n\n', mfilename)
	disp(errEvent)
	msg = -1;
	if nargout > 1
		varargout{1} = showdaqevents(NI.ai);
		return
	end
end

% get event log
% EventLog = showdaqevents(handles.iodev.NI.ai);

% delete and clear ch0 object
try
	delete(NI.chI);
catch errEvent
	fprintf('%s: problem deleting NI.chI!\n\n\n', mfilename)
	disp(errEvent)
	msg = -2;
	if nargout > 1
		varargout{1} = showdaqevents(NI.ai);
		return
	end
end	

% delete and clear ai object
try
	if nargout > 1
		varargout{1} = showdaqevents(NI.ai);
	end
	delete(NI.ai);
catch errEvent
	fprintf('%s: problem deleting NI.ai!\n\n\n', mfilename)
	disp(errEvent)
	msg = -3;
	if nargout > 1
		varargout{1} = showdaqevents(NI.ai);
		return
	end
end

msg = 0;
	


		