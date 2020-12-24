function data = loadTimeSeriesData(timeseries, interval, downsample_factor, electrodes)
%LOADTIMESERIESDATA load time series data in a specific interval
%   D = LOADTIMESERIESDATA(TIMESERIES, INTERVAL) is the
%   event-aligned data for TIMESERIES in INTERVAL, specified in
%   seconds. D is of shape electrodes x time.
%
%   D = LOADTIMESERIESDATA(TIMESERIES, INTERVAL, DOWNSAMPLE_FACTOR)
%   specifies a temporal downsampling for D. Default is 1.
%   
%   D = LOADTIMESERIESDATA(TIMESERIES, INTERVAL, DOWNSAMPLE_FACTOR, ELECTRODES)
%   specifies what electrode to pull data for. Default is []:
%
%   []  - all electrodes
%   [ints] - list of electrodes (1-indexed)

if ~exist('interval','var') || isempty(interval)
    interval = [0 Inf];
end

if ~exist('downsample_factor','var') || isempty(downsample_factor)
    downsample_factor = 1;
end

if ~exist('electrode', 'var')
    electrode = [];
end

if length(electrodes) > 1
    fs = timesries.starting_time_rate;
    data = NaN(diff(interval) * fs, length(electrodes));
    for i = 1:length(electrodes)
        data(:,i) = loadTimeSeriesData(timeseries, interval, ...
            downsample_factor, electrodes(i));
    end
else
    
    dims = timeseries.data.dims;
    
    if interval(1)
        if isempty(timeseries.starting_time)
            start_ind = fastsearch(timeseries.timestamps, interval(1), 1);
        else
            fs = timeseries.starting_time_rate;
            t0 = timeseries.starting_time;
            if interval(1) < t0
                error('interval bounds outside of time range');
            end
            start_ind = (interval(1) - t0) * fs;
        end
    else
        start_ind = 1;
    end
    
    if isfinite(interval(2))
        
        if isempty(timeseries.starting_time)
            end_ind = fastsearch(timeseries.timestamps, interval(2), -1);
        else
            fs = timeseries.starting_time_rate;
            t0 = timeseries.starting_time;
            if interval(2) > (dims(end) * fs + t0)
                error('interval bounds outside of time range');
            end
            end_ind = (interval(2) - t0) * fs;
        end
    else
        end_ind = Inf;
    end
    
    start = ones(1, length(dims));
    start(end) = start_ind;
    
    count = dims;
    count(end) = round((end_ind - start_ind) / downsample_factor);
    
    if ~isempty(electrode)
        start(end-1) = electrode;
        count(end-1) = 1;
    end
    
    if downsample_factor == 1
        data = timeseries.data.load_h5_style(start, count);
    else
        stride = ones(1, length(dims));
        stride(end) = downsample_factor;
        data = timeseries.data.load_h5_style(start, stride, end)';
    end
    
end

data = data * timeseries.data_conversion;