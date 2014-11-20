function NI = ai_init(iface, Dnum)
%--------------------------------------------------------------------------
% NI = ai_init.m
%--------------------------------------------------------------------------
% chirocall program
% TytoLogy Project
%--------------------------------------------------------------------------
% initializes nidaq system for analog acq
%------------------------------------------------------------------------
% Input Arguments:
% 	iface		must be 'NI'
%	Dnum		device id (usually 'Dev1')
% 
% Output Arguments:
% 	NI		struct containing settings for requested type
% 		NI.ai		analog input object
% 		NI.chI	analog input channel object
%------------------------------------------------------------------------
% See also: NICal
%------------------------------------------------------------------------

%--------------------------------------------------------------------------
% Sharad J Shanbhag
% sshanbhag@neomed.edu
%--------------------------------------------------------------------------
% Created: 20 November2014 (SJS)
% 				Created from nidaq_ai_init.m (NICal)
% 
% Revisions:
%--------------------------------------------------------------------------

disp('...starting NI hardware...');

if ~strcmpi(iface, 'NI')
	error('%s: invalid interface %s', mfilename, iface);
end

%------------------------------------------------------------------------
%------------------------------------------------------------------------
% Now, Initialize the NI board (PCIe-6351)
%------------------------------------------------------------------------
%------------------------------------------------------------------------
% 'nidaq' specifies the national instruments device with traditional
% DAQ Toolbox interface, Device number 1 (get this from the 
% NI Measurement & Automation Explorer (a.k.a., MAX) program)
%------------------------------------------------------------------------

%------------------------------------------------------------------------
% CONFIGURE ANALOG INPUT SUBSYSTEM
%------------------------------------------------------------------------
fprintf('Initializing NIDAQ device for analog input...')
try
	ai = analoginput('nidaq', Dnum);
	fprintf('...done\n')
catch errEvent
	fprintf('\nProblem while initializing NIDAQ device!\n\n')
	disp(errEvent)
	return
end

% create AI channel
fprintf('creating analog input channel objects...')
chI = addchannel(ai, [0 1]);
fprintf('...done\n');

ai.Channel(1).ChannelName = 'AI0';
ai.Channel(2).ChannelName = 'AI1';

%-------------------------------------------------------
% save in NI struct
%-------------------------------------------------------
NI.ai = ai;
NI.chI = chI;
NI.status = 1;



