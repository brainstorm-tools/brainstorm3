function [data] = eepv4_read(fn);

% eepv4_read reads data from aa cnt or avg file
%
% data = eepv4_read(filename, sample1, sample2)
%
% where sample1 and sample2 are the begin and end sample of the data
% to be read, starting at one sample2 being non-inclusive
%
% data then contains:
%
% data.version          ... version of the software
% data.samples          ... array [nchan x npnt] containing eeg data (uV)
% data.triggers         ... array [offset_in_file, offset_in_segment, seconds_in_file, seconds_in_segment, label, duration, type, code, condition, videofilename, impedances] trigger info, where each the fields are:
%                             offset_in_file     ... sample offset(starting at 0) of the trigger from the beginning of the file
%                             offset_in_segment  ... sample offset(starting at 0) of the trigger from the beginning of the segment
%                             seconds_in_file    ... offset in seconds since beginning of the file
%                             seconds_in_segment ... offset in seconds since beginning of the segment
%                             label              ... trigger label
%                             duration           ... duration in samples, starting at 0
%                             type               ... evt type, 1=marker, 4=epoch
%                             condition          ... evt condition, if used
%                             videofilename      ... evt video filename, if used
%                             impedances         ... evt impedances, if used
% data.start_in_seconds ... scalar showing the time in seconds of this segments since start of file

error('could not locate mex file');
