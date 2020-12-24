function [D, tt] = loadTrialAlignedTimeSeriesData(nwb, timeseries, window, align_to, conditions, downsample_factor, electrode)
%LOADTRIALALIGNEDTIMESERIESDATA load trial-aligned time series data
%   D = LOADTRIALALIGNEDTIMESERIESDATA(NWB, TIMESERIES, WINDOW) is the
%   trial-aligned data for TIMESERIES in NWB with intervals WINDOW,
%   in seconds, for all electrodes. D is of shape trials x electrodes x time.
%
%   D = LOADTRIALALIGNEDTIMESERIESDATA(NWB, TIMESERIES, WINDOW, ALIGN_TO)
%   aligns data to the column named ALIGN_TO. Default is 'start_time'.
%
%   D = LOADTRIALALIGNEDTIMESERIESDATA(NWB, TIMESERIES, WINDOW, ALIGN_TO, CONDITIONS)
%   takes a containers.Map object where the keys are the column names and
%   the values are the tests. A function can be entered for the value here, and
%   Only columns where the function evaluates as true will be used. If a
%   non-funcion is entered, an equality test is used.
%
%   D = LOADTRIALALIGNEDTIMESERIESDATA(NWB, TIMESERIES, WINDOW, ALIGN_TO, CONDITIONS, DOWNSAMPLE_FACTOR)
%   specifies a temporal downsampling for D. Default is 1.
%   
%   D = LOADTRIALALIGNEDTIMESERIESDATA(NWB, TIMESERIES, WINDOW, ALIGN_TO, CONDITIONS, DOWNSAMPLE_FACTOR, ELECTRODES)
%   specifies what electrode to pull data for. Default is []:
%
%   []  - all electrodes
%   [ints] - list of electrodes (1-indexed)

if ~exist('downsample_factor', 'var') || isempty(downsample_factor)
    downsample_factor = 1;
end

if ~exist('electrode', 'var')
    electrode = [];
end

if ~exist('align_to', 'var')
    align_to = 'start_time';
end

trials = nwb.intervals_trials;

if strcmp(align_to, 'start_time')
    times = trials.start_time.data.load;
elseif strcmp(align_to, 'stop_time')
    times = trials.stop_time.data.load;
else
    times = trials.vectordata.get(align_to);
end

trials_to_take = true(length(times),1);
if exist('conditions', 'var')
    keys = conditions.keys;
    for i = 1:length(keys)
        key = keys{i};
        val = conditions(key);
        if strcmp(key, 'start_time')
            col = trials.start_time;
        elseif strcmp(key, 'stop_time')
            col = trials.stop_time;
        else
            col = trials.vectordata.get(key);
        end
        
        if isa(val, 'function_handle')
            trials_to_take = val(col.data.load) & trials_to_take;
        else
            trials_to_take = (col.data.load == val) & trials_to_take;
        end
    end
end

times = times(trials_to_take);

D = util.loadEventAlignedTimeSeriesData(timeseries, window, times, ...
    downsample_factor, electrode);

tt = linspace(window(1), window(2), size(D, 3));


