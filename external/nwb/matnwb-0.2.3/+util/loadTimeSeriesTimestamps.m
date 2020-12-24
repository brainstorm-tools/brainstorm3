function timestamps = loadTimeSeriesTimestamps(timeseries, interval, downsample_factor)
%LOADTIMESERIESTIMESTAMPS load times within a time interval from a timeseries
%
%   TIMESTAMPS = LOADTIMESERIESTIMESTAMPS(TIMESERIES, INTERVAL) TIMESERIES
%   is a matnwb TimeSeries object. This function returns the TIMESTAMPS 
%   within INTERVAL. This works for timeseries objects that are specified
%   using timestamps or by rate and starting_time.
%
%   TIMESTAMPS = LOADTIMESERIESTIMESTAMPS(TIMESERIES, INTERVAL, DOWNSAMPLE_FACTOR)
%   return only every DOWNSAMPLE_FACTOR TIMESTAMP.

if ~exist('interval', 'var') || isempty(interval)
    interval = [0 Inf];
end

if ~exist('downsample_factor', 'var') || isempty(downsample_factor)
    downsample_factor = 1;
end

dims = timeseries.data.dims;

if ~isempty(timeseries.starting_time)
    fs = timeseries.starting_time_rate;
    if isinf(interval(2))
        interval(2) = dims(1)/fs + timeseries.starting_time;
    end
    timestamps = interval(1):1/fs * downsample_factor:interval(2);
    
else
    if downsample_factor ~= 1
        warning(['Downsampling a timestamps of a timeseries that may'...
        'not be uniformly sampled. This may have unintended behavior'])
    end
    start_ind = fastsearch(timeseries.timestamps, interval(1), 1);
    if isinf(interval(2))
        timestamps = timeseries.timestamps.load_h5_style(start_ind, [], downsample_factor);
    else
        end_ind = fastsearch(timeseries.timestamps, interval(2), -1);
        timestamps = timeseries.timestamps.load_h5_style(start_ind, end_ind - start_ind, downsample_factor);
    end
end