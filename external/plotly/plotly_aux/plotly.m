function [response] = plotly(varargin)
% plotly - create a graph in your plotly account
%   [response] = plotly(x1,y1,x2,y2,..., kwargs)
%   [response] = plotly({data1, data2, ...}, kwargs)
%       x1,y1 - arrays
%       data1 - a data struct with styling information
%       kwargs - an optional argument struct
%
% See also plotlylayout, plotlystyle, signin, signup
%
% For full documentation and examples, see https://plot.ly/api
origin = 'plot';
if isstruct(varargin{end})
    structargs = varargin{end};
    f = lower(fieldnames(structargs));
    if ~any(strcmp('filename',f))
        structargs.filename = NaN;
    end
    if ~any(strcmp('fileopt',f))
        structargs.fileopt = NaN;
    end
    args = varargin(1:(end-1));
else
    structargs = struct('filename', NaN,'fileopt',NaN);
    args = varargin(1:end);
end

response = makecall(args, origin, structargs);

end