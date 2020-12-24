function D = loadEventAlignedTimeSeriesData(timeseries, window, times, downsample_factor, electrodes)
%LOADEVENTALIGNEDTIMESERIESDATA load event-aligned time series data
%   D = LOADEVENTALIGNEDTIMESERIESDATA(TIMESERIES, WINDOW, TIMES) is the
%   event-aligned data for TIMESERIES in intervals with WINDOW around TIMES,
%   in seconds, for all electrodes. D is of shape trials x electrodes x time.
%
%   D = LOADEVENTALIGNEDTIMESERIESDATA(TIMESERIES, WINDOW, TIMES, DOWNSAMPLE_FACTOR)
%   specifies a temporal downsampling for D. Default is 1.
%   
%   D = LOADEVENTALIGNEDTIMESERIESDATA(TIMESERIES, WINDOW, TIMES, DOWNSAMPLE_FACTOR, ELECTRODES)
%   specifies what electrode to pull data for. Default is []:
%
%   []  - all electrodes
%   [ints] - list of electrodes (1-indexed)

if ~exist('downsample_factor','var') || isempty(downsample_factor)
    downsample_factor = 1;
end

if ~exist('electrode','var')
    electrode = [];
end

fs = timeseries.starting_time_rate;
inds_len = diff(window) * fs / downsample_factor;

dims = timeseries.data.dims;

if isempty(electrode)
    D = NaN(length(times), dims(1), int16(inds_len));
    for i = 1:length(times)
        D(i,:,:) = util.loadTimeSeriesData(timeseries, window + times(i), ...
            downsample_factor, electrodes);
    end
else
    D = NaN(length(times), inds_len);
    for i = 1:length(times)
        D(i,:) = util.loadTimeSeriesData(timeseries, window + times(i), ...
            downsample_factor, electrodes);
    end
end
