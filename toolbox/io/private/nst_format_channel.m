function [channel_label, measure] = nst_format_channel(isrc, idet, measure)
% NST_FORMAT_CHANNEL make channel label from source, dectector and measure information.
%
%   CHANNEL_LABEL = NST_FORMAT_CHANNEL(ISRC, IDET, MEAS)
%
%        ISRC (int >= 0): source index
%        IDET (int >= 0): extracted detector index
%        MEAS (int | str): measure value. 
%                          Either wavelength (int) or Hb type (str)
%                          -> 'HbO', 'HbR', 'HbT'
%
%       CHANNEL_LABEL (str): 
%           formatted as 'SxDyWLz' or 'SxDyHbt', where:
%               x: source index
%               y: detector index
%               z: wavelength
%               t: Hb type (O, R, T).
%           Examples: S1D2WL685, S3D01HbR
%
%   See also NST_UNFORMAT_CHANNEL

% stub:
assert(isrc >= 0);
assert(idet >= 0);

if nargin >= 3
    assert(isnumeric(measure) || (ischar(measure) && ...
        ismember(measure, {'HbO', 'HbR', 'HbT'})));
    
    if isnumeric(measure)
        assert(measure >= 0);
        assert(round(measure) == measure);
        measure = sprintf('WL%d', measure);
    end
else
    measure = '';
end

channel_label = sprintf('S%dD%d%s', isrc, idet, measure);
end