function strDatetime = str_datetime(s, datetimeFormat)
% STR_DATETIME: Reformat a datetime object or string to 'yyyy-MM-ddTHH:mm:ss.SSS'
%               using datetime()

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Raymundo Cassani, 2026

% Parse inputs
if (nargin < 2) || isempty(datetimeFormat)
    datetimeFormat = [];
end
% Output format, used with datetime()
outFormat = 'yyyy-MM-dd''T''HH:mm:ss.SSS';
% Clean string
if ischar(s)
    s = strtrim(strrep(s, char(0), ''));
end
% Check various input formats
try
    % Datetime object already
    if isdatetime(s)
        ts = s;
    % Input is POSIX time (or Unix time)
    elseif isnumeric(s)
        ts = datetime(s, 'ConvertFrom', 'posixtime');
    % Format of input is provided
    elseif ~isempty(datetimeFormat)
        ts = datetime(s, 'InputFormat', datetimeFormat);
    % dd-MMM-yyyy HH.mm.ss
    elseif isequal(find(s == '-'), [3 7]) && isequal(find(s == '.'), [15 18]) && (length(s) == 20)
        ts = datetime(s, 'InputFormat', 'dd-MMM-yyyy HH.mm.ss');
    % yyyy-MM-dd''T''HH:mm:ss[.S | .SS | .SSS | ...]
    elseif isequal(find(s == 'T'), 11) && (length(s) >= 19)
        datetimeFormat = 'yyyy-MM-dd''T''HH:mm:ss';
        if length(s) > 19
            nDecimals = length(s) - 19 - 1;
            datetimeFormat = strjoin({'yyyy-MM-dd''T''HH:mm:ss', repmat('S', 1, nDecimals)}, '.');
        end
        ts = datetime(s, 'InputFormat', datetimeFormat);
    % dd-MMM-yyyy HH:mm
    elseif isequal(find(s == '-'), [3 7]) && isequal(find(s == ':'), 15) && (length(s) == 17)
        ts = datetime(s, 'InputFormat', 'dd-MMM-yyyy HH:mm');
    else
        strDatetime = [];
        return
    end
    % Convert to string
    ts.Format = outFormat;
    strDatetime = char(ts);
catch
    strDatetime = [];
end
