function nwbfile = AddEyePos(nwbfile, mwk_path, labels)

if ~exist('labels','var') || isempty(labels)
    labels = {'eye_h', 'eye_v'};
end

[~, fname] = fileparts(mwk_path);

reverse_codec = getReverseCodec(mwk_path);

% get eye position
events = getEvents(mwk_path, reverse_codec(labels{1}));
time_us = double([events.time_us]);
timestamps = (time_us - min(time_us))/1000000;
eye_h = [events.data];

events = getEvents(mwk_path, reverse_codec(labels{2}));
eye_v = [events.data];

time_us2 = double([events.time_us]);

keep = time_us == time_us2;

disp(['throwing out ' num2str(sum(~keep)) ' mismatched eye tracking times'])

% times were mismatched between eye_h and eye_v
timestamps = timestamps(keep)';
eye_h = eye_h(keep);
eye_v = eye_v(keep);

data = [eye_h', eye_v'];

spatial_series = types.core.SpatialSeries( ...,
    'timestamps', timestamps, ...
    'data', data, ...
    'reference_frame', 'h,v', ...
    'data_unit', 'unknown');

eye_tracking = types.core.EyeTracking( ...
    'spatialseries', spatial_series);

nwbfile.acquisition.set('Eye Tracking', eye_tracking);