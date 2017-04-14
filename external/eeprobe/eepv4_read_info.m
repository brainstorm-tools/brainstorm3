function [info] = eepv4_read_info(fn);

% eepv4_read_info reads a cnt or avg file
% and returns a structure containing data information.
%
% info = eepv4_read_info(filename)
%
% info then contains:
%
% info.version       ... version of the software
% info.channel_count ... number of channels
% info.channels      ... array [1 x channel_count] of channel labels
% info.sample_count  ... number of samples
% info.sample_rate   ... sample rate (Hz)
% info.trigger_count ... number of triggers
% info.triggers      ... array [offset_in_file, offset_in_segment, seconds_in_file, seconds_in_segment, label, duration, type, code, condition, videofilename, impedances] trigger info, where each the fields are:
%                          offset_in_file  ... sample offset(starting at 0) of the trigger from the beginning of the file
%                          seconds_in_file ... offset in seconds since beginning of the file
%                          label           ... trigger label
%                          duration        ... duration in samples, starting at 0
%                          type            ... evt type, 1=marker, 4=epoch
%                          condition       ... evt condition, if used
%                          videofilename   ... evt video filename, if used
%                          impedances      ... evt impedances, if used

error('could not locate mex file');
