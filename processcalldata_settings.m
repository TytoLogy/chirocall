%------------------------------------------------------------------------
% processcalldata_settings.m
%------------------------------------------------------------------------
% Used to set data filtering for processcalldata function
%------------------------------------------------------------------------
% See also: processcalldata(), chirocall()
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
% default "chunk" size for wav file output in "autochunk" mode (in seconds)
%------------------------------------------------------------------------
default_chunk_min = 0.5;

%------------------------------------------------------------------------
% decimation factor for plotting the raw data in single-chunk mode
%------------------------------------------------------------------------
deci_factor = 10;


%------------------------------------------------------------------------
% Bandpass filter settings
%------------------------------------------------------------------------

% turns filtering on ('yes') or off ('no')
FILTER_DATA = 'yes';

% high-pass cutoff frequency (Hz)
fc_high = 1000;

% low-pass cutoff frequency (Hz)
fc_low = 150000;

% filter order (used to change "strength" of the filter)
filter_order = 3;

% filter type ('butterworth' is typical)
filter_type = 'butterworth';

% filter mode ('highpass', 'lowpass', 'bandstop', 'bandpass')
filter_mode = 'bandstop';