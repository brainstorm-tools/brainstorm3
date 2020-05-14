function [isrc, idet, measure, channel_type] = nst_unformat_channel(channel_label, warn_bad_channel)
% NST_UNFORMAT_CHANNEL extract source, dectector and measure information from channel label.
%
%   [ISRC, IDET, MEAS, CHAN_TYPE] = NST_UNFORMAT_CHANNEL(CHANNEL_LABEL)
%       CHANNEL_LABEL (str): 
%           formatted as 'SxDyWLz' or 'SxDyHbt', where:
%               x: source index
%               y: detector index
%               z: wavelength
%               t: Hb type (O, R, T).
%           Examples: S1D2WL685, S01D7WL830, S3D01HbR
%
%        ISRC (int): extracted source index
%        IDET (int): extracted detector index
%        MEAS (int | str): extracted measure value
%        CHAN_TYPE (int): extracted channel type.
%
%        If channel cannot be unformatted then all returned values are nan
%
%   See also NST_UNFORMAT_CHANNELS, NST_CHANNEL_TYPES, NST_FORMAT_CHANNEL
assert(ischar(channel_label));

if nargin < 2
    warn_bad_channel = 0;
end

CHAN_RE = '^S([0-9]+)D([0-9]+)(WL\d+|HbO|HbR|HbT)$';
toks = regexp(channel_label, CHAN_RE, 'tokens');
if isempty(toks)
    if warn_bad_channel
        warning('NIRSTORM:MalformedChannelLabel', ...
            ['Malformed channel label:', channel_label, ...
            '. Should be SxDyWLz or SxDyHb(O|R|T)']);
    end
    isrc = nan;
    idet = nan;
    measure = nan;
    channel_type = nan;
else
    isrc = str2double(toks{1}{1});
    idet = str2double(toks{1}{2});
    measure = toks{1}{3};
    
    measure_types = nst_measure_types();
    if ~isempty(strfind(measure, 'WL'))
        channel_type = measure_types.WAVELENGTH;
        measure = str2double(measure(3:end));
    else
        channel_type = measure_types.HB;
    end
end

end