function coeffs = get_filter(Fs)
%------------------------------------------------------------------------
% get_filter.m
%------------------------------------------------------------------------
% returns filter coefficients using settings in 
% processcalldata_settings.m
%
%	Input args:
%		Fs		sample rate
% 
%	Output args:
%		coeffs	struct with coefficients stored in
% 					coeffs.a, coeffs.b
%------------------------------------------------------------------------
% See also: 
%------------------------------------------------------------------------

%------------------------------------------------------------------------
% Sharad J. Shanbhag
% sshanbhag@neomed.edu
%------------------------------------------------------------------------
% Created: 17 December 2014 (SJs)
%
% Revisions:
%------------------------------------------------------------------------

%------------------------------------------------------------------------
% load filter settings
%------------------------------------------------------------------------
processcalldata_settings;

%------------------------------------------------------------------------
% build filter
%------------------------------------------------------------------------
% Nyquist freq.
Fn = Fs / 2;

switch filter_type
	case 'butterworth'
		
		switch filter_mode
			case 'highpass',
				[coeffs.b, coeffs.a] = butter(filter_order, fc_high / Fn, 'high');

			case 'lowpass', 
				[coeffs.b, coeffs.a] = butter(filter_order, fc_low / Fn, 'low');
				
			case 'bandstop', 
				[coeffs.b, coeffs.a] = butter(filter_order, ...
															[fc_high fc_low] ./ Fn, 'stop');

			case 'bandpass',
				[coeffs.b, coeffs.a] = butter(filter_order, ...
														[fc_high fc_low] ./ Fn, 'bandpass');
				
			otherwise,
				error('%s: unsupported filter mode <%s>', mfilename, filter_mode);
		
		end
		
	otherwise,
		error('%s: unsupported filter type <%s>', mfilename, filter_type);
end

